/*
 * semarv: AccurateRip verification for Semplice.
 *
 * Usage:  semarv track01.cdda.wav track02.cdda.wav ... [> report.txt]
 *
 * Give it the WAVs of a whole audio CD, in track order, exactly as cdparanoia -B produces them.
 * A "track00" file (audio hidden before track 1) is used only to place track 1 correctly on the
 * disc, and is not itself checked. semarv then:
 *   1. works out the disc's AccurateRip identifiers from the track lengths;
 *   2. downloads the disc's entry from the AccurateRip database (using curl);
 *   3. calculates each track's AccurateRip v1 and v2 checksums and compares them with the database.
 *
 * The report ends with a single RESULT line, which Semplice reads:
 *   RESULT: MATCH <lowest confidence>    every track matched
 *   RESULT: PARTIAL <matched>/<tracks>   some tracks matched, some did not
 *   RESULT: NOMATCH                      the disc is in the database but no track matched
 *   RESULT: NOTINDB                      the disc is not in the AccurateRip database
 *   RESULT: ERROR <reason>               the check could not be done
 *
 * Offset mode ("Configure AccurateRip"): semarv --offset tracks.txt key01.wav key02.wav ...
 *   tracks.txt holds one line per audio track: <track number> <length> <start>, in sectors (from cdparanoia -Q).
 *   Each keyNN.wav is sectors 350 to 550 of track NN, ripped at read offset 0. AccurateRip stores, for every
 *   track of every pressing, a checksum of the track's sector 450 (sum of sample x position, positions 1-588).
 *   semarv slides along each rip looking for that checksum: where it turns up shows how far the drive's
 *   reading is displaced, which is the drive's read offset. A pressing counts only if every key track agrees.
 *   It ends with a single RESULT line:
 *   RESULT: OFFSETS <disc id> <offset> [<offset> ...]   every offset some pressing of this disc points to
 *   RESULT: NOMATCH                                    the disc is in the database but no pressing matches
 *   RESULT: NOTINDB / RESULT: ERROR <reason>           as above
 *
 * Needs nothing but a C compiler to build, and curl at run time. Build it on each platform as
 * (names as Giocoso's exec programs: semarv-<macos|linux>-<arm64|x86_64>):
 *   cc -O2 -static -o semarv-linux-x86_64 semarv.c                          (Linux, Intel/AMD)
 *   cc -O2 -static -o semarv-linux-arm64 semarv.c                           (Linux, 64-bit ARM)
 *   cc -O2 -mmacosx-version-min=10.13 -o semarv-macos-x86_64 semarv.c       (Intel Mac)
 *   cc -O2 -mmacosx-version-min=11.0 -o semarv-macos-arm64 semarv.c         (Apple Silicon Mac)
 *
 * Exit status: 0 for MATCH, 1 for anything else.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

#define SAMPLES_PER_SECTOR 588                 /* 2352 bytes / 4 bytes per stereo sample */
#define SKIP_SAMPLES (5 * SAMPLES_PER_SECTOR)  /* AccurateRip ignores 5 sectors at the disc's very start and end */
#define MAXTRACKS 99

typedef struct {
  const char *path;
  long data_offset;        /* where the PCM data starts in the file */
  uint32_t samples;        /* number of stereo samples */
  uint32_t v1, v2;         /* AccurateRip checksums */
  int confidence;          /* best matching confidence found in the database; -1 = no match */
} Track;

static uint32_t rd32(const unsigned char *p) { return (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 | (uint32_t)p[3] << 24; }
static uint16_t rd16(const unsigned char *p) { return (uint16_t)(p[0] | p[1] << 8); }

/* Find the PCM data in a RIFF WAV, checking it is CD audio: 16-bit, stereo, 44.1kHz */
static int open_wav(Track *t, char *why, size_t whylen) {
  FILE *f = fopen(t->path, "rb");
  unsigned char hdr[12], ch[8], fmt[16];
  int have_fmt = 0;
  if (!f) { snprintf(why, whylen, "cannot open %s", t->path); return -1; }
  if (fread(hdr, 1, 12, f) != 12 || memcmp(hdr, "RIFF", 4) || memcmp(hdr + 8, "WAVE", 4)) {
    snprintf(why, whylen, "%s is not a WAV file", t->path); fclose(f); return -1;
  }
  while (fread(ch, 1, 8, f) == 8) {
    uint32_t size = rd32(ch + 4);
    if (!memcmp(ch, "fmt ", 4)) {
      if (size < 16 || fread(fmt, 1, 16, f) != 16) break;
      if (rd16(fmt) != 1 || rd16(fmt + 2) != 2 || rd32(fmt + 4) != 44100 || rd16(fmt + 14) != 16) {
        snprintf(why, whylen, "%s is not CD audio (16-bit stereo 44.1kHz PCM)", t->path); fclose(f); return -1;
      }
      have_fmt = 1;
      fseek(f, (long)(size - 16 + (size & 1)), SEEK_CUR);
    } else if (!memcmp(ch, "data", 4)) {
      if (!have_fmt) break;
      t->data_offset = ftell(f);
      t->samples = size / 4;
      fclose(f);
      return 0;
    } else {
      fseek(f, (long)(size + (size & 1)), SEEK_CUR);
    }
  }
  snprintf(why, whylen, "%s has no usable audio data", t->path);
  fclose(f);
  return -1;
}

/* AccurateRip v1 and v2 checksums of one track. Samples are 32-bit words (left channel in the
   low 16 bits), multiplied by their 1-based position. The first track skips its first 5 sectors
   and the last track its last 5 sectors (drives cannot read those reliably). */
static int checksum(Track *t, int first, int last) {
  FILE *f = fopen(t->path, "rb");
  static unsigned char buf[4 * 65536];
  uint32_t from = first ? SKIP_SAMPLES : 0;
  uint32_t to = last ? (t->samples > SKIP_SAMPLES ? t->samples - SKIP_SAMPLES : 0) : t->samples;
  uint32_t v1 = 0, v2 = 0, pos = 1, left = t->samples;
  if (!f) return -1;
  fseek(f, t->data_offset, SEEK_SET);
  while (left > 0) {
    size_t want = left < 65536 ? left : 65536, got = fread(buf, 4, want, f), i;
    if (got == 0) break;
    for (i = 0; i < got; i++, pos++) {
      if (pos >= from && pos <= to) {
        uint32_t s = rd32(buf + 4 * i);
        uint64_t prod = (uint64_t)s * pos;
        v1 += s * pos;
        v2 += (uint32_t)(prod & 0xFFFFFFFFu) + (uint32_t)(prod >> 32);
      }
    }
    left -= (uint32_t)got;
  }
  fclose(f);
  t->v1 = v1; t->v2 = v2;
  return left == 0 ? 0 : -1;
}


static int digit_sum(uint32_t n) { int s = 0; while (n) { s += n % 10; n /= 10; } return s; }

/* Downloads a disc's AccurateRip entry. On failure prints the RESULT line itself and returns -1. */
static int fetch_db(const char *url, unsigned char **data, long *len) {
  char tmp[] = "/tmp/semarvXXXXXX", cmd[512];
  int fd = mkstemp(tmp);
  if (fd < 0) { printf("RESULT: ERROR cannot create a temporary file\n"); return -1; }
  close(fd);
  snprintf(cmd, sizeof cmd, "curl -s -f -m 30 -A 'Semplice' -o '%s' '%s'", tmp, url);
  int rc = system(cmd);
  FILE *db = fopen(tmp, "rb");
  *data = NULL; *len = 0;
  if (db) {
    fseek(db, 0, SEEK_END); *len = ftell(db); rewind(db);
    if (*len > 0 && (*data = malloc((size_t)*len)) && fread(*data, 1, (size_t)*len, db) != (size_t)*len) *len = 0;
    fclose(db);
  }
  remove(tmp);
  if (rc != 0 || *len <= 0) {
    /* curl -f fails on HTTP errors: a 404 means the disc simply isn't in the database */
    if (WIFEXITED(rc) && WEXITSTATUS(rc) == 22) { printf("RESULT: NOTINDB\n"); return -1; }
    printf("RESULT: ERROR could not reach the AccurateRip database\n"); return -1;
  }
  return 0;
}

#define KEY_FIRST_SECTOR 350                   /* each key rip starts at this sector of its track... */
#define KEY_SECTOR 450                         /* ...and AccurateRip's offset-finding checksum covers this one */
#define MAXPRESS 64

/* Offset mode: finds every read offset at which some pressing of the disc matches the key rips */
static int offset_mode(int argc, char **argv) {
  uint32_t begin[MAXTRACKS], length[MAXTRACKS];
  int n = 0, i, a;
  FILE *tf = fopen(argv[2], "r");
  if (!tf) { printf("RESULT: ERROR cannot open %s\n", argv[2]); return 1; }
  { unsigned t, l, b; while (n < MAXTRACKS && fscanf(tf, "%u %u %u", &t, &l, &b) == 3) { length[n] = l; begin[n] = b; n++; } }
  fclose(tf);
  if (n == 0) { printf("RESULT: ERROR no tracks listed in %s\n", argv[2]); return 1; }

  uint32_t id1 = 0, id2 = 0, cddb_n = 0, cddb, leadout = begin[n - 1] + length[n - 1];
  for (i = 0; i < n; i++) {
    id1 += begin[i];
    id2 += (begin[i] ? begin[i] : 1) * (uint32_t)(i + 1);
    cddb_n += digit_sum((begin[i] + 150) / 75);
  }
  id1 += leadout;
  id2 += leadout * (uint32_t)(n + 1);
  cddb = ((cddb_n % 255) << 24) | ((((leadout + 150) / 75) - ((begin[0] + 150) / 75)) << 8) | (uint32_t)n;
  char url[256];
  snprintf(url, sizeof url, "http://www.accuraterip.com/accuraterip/%x/%x/%x/dBAR-%03d-%08x-%08x-%08x.bin",
           id1 & 0xF, (id1 >> 4) & 0xF, (id1 >> 8) & 0xF, n, id1, id2, cddb);
  printf("Disc: %d tracks, AccurateRip IDs %08x-%08x-%08x\n", n, id1, id2, cddb);

  unsigned char *data = NULL; long len = 0;
  if (fetch_db(url, &data, &len)) return 1;

  /* Each pressing's offset-finding checksums, track by track */
  static uint32_t c450[MAXPRESS][MAXTRACKS];
  int np = 0; long p = 0;
  while (p + 13 <= len && np < MAXPRESS) {
    int cnt = data[p];
    if (cnt != n || rd32(data + p + 1) != id1 || rd32(data + p + 5) != id2 || rd32(data + p + 9) != cddb) break;
    p += 13;
    if (p + 9L * cnt > len) break;
    for (i = 0; i < cnt; i++, p += 9) c450[np][i] = rd32(data + p + 5);
    np++;
  }
  free(data);
  if (np == 0) { printf("RESULT: NOTINDB\n"); return 1; }

  /* For each pressing: the offsets every key track agrees on. hits[k][o] counts key tracks matching. */
  int maxoff = 0;
  static int *hits[MAXPRESS]; int need[MAXPRESS];
  memset(need, 0, sizeof need);
  int span = 0;
  for (a = 3; a < argc; a++) {
    const char *base = strrchr(argv[a], '/'); base = base ? base + 1 : argv[a];
    int trk = 0;
    while (*base && (*base < '0' || *base > '9')) base++;
    trk = atoi(base);
    if (trk < 1 || trk > n) { printf("RESULT: ERROR %s does not name a track on this disc\n", argv[a]); return 1; }
    Track t = { argv[a], 0, 0, 0, 0, -1 };
    char why[512];
    if (open_wav(&t, why, sizeof why)) { printf("RESULT: ERROR %s\n", why); return 1; }
    if (t.samples < (KEY_SECTOR - KEY_FIRST_SECTOR + 1) * SAMPLES_PER_SECTOR) { printf("RESULT: ERROR %s is too short\n", argv[a]); return 1; }
    uint32_t *x = malloc(4 * (size_t)t.samples);
    FILE *f = fopen(t.path, "rb");
    if (!x || !f) { printf("RESULT: ERROR could not read %s\n", argv[a]); return 1; }
    fseek(f, t.data_offset, SEEK_SET);
    unsigned char b4[4]; uint32_t k;
    for (k = 0; k < t.samples && fread(b4, 1, 4, f) == 4; k++) x[k] = rd32(b4);
    fclose(f);
    if (k < t.samples) { printf("RESULT: ERROR could not read %s\n", argv[a]); return 1; }

    /* The window of 588 samples that would be sector 450 if the drive had no offset starts here */
    int zero = (KEY_SECTOR - KEY_FIRST_SECTOR) * SAMPLES_PER_SECTOR;
    int last = (int)t.samples - SAMPLES_PER_SECTOR;          /* last possible window start */
    if (!span) { span = last + 1; maxoff = zero; }
    for (i = 0; i < np; i++) {
      if (!hits[i]) hits[i] = calloc((size_t)span, sizeof(int));
      if (c450[i][trk - 1]) need[i]++;                       /* a stored 0 (silence) proves nothing: skip it */
    }
    /* Rolling checksum: S(s) = sum of x[s+j]*(j+1); W(s) = plain sum of the same window */
    uint32_t S = 0, W = 0; int j, s;
    for (j = 0; j < SAMPLES_PER_SECTOR; j++) { S += x[j] * (uint32_t)(j + 1); W += x[j]; }
    for (s = 0; s <= last && s < span; s++) {
      for (i = 0; i < np; i++) if (c450[i][trk - 1] && S == c450[i][trk - 1]) hits[i][s]++;
      if (s < last) {
        S = S - W + (uint32_t)SAMPLES_PER_SECTOR * x[s + SAMPLES_PER_SECTOR];
        W = W - x[s] + x[s + SAMPLES_PER_SECTOR];
      }
    }
    free(x);
  }
  if (!span) { printf("RESULT: ERROR no key rips given\n"); return 1; }

  /* Gather the offsets, without duplicates, smallest first */
  static int found[4096]; int nf = 0, s;
  for (s = 0; s < span; s++)
    for (i = 0; i < np; i++)
      if (need[i] > 0 && hits[i][s] == need[i]) {
        int off = s - maxoff, d, dup = 0;
        for (d = 0; d < nf; d++) if (found[d] == off) dup = 1;
        if (!dup && nf < 4096) { found[nf++] = off; printf("Pressing %d matches at read offset %+d\n", i + 1, off); }
      }
  if (nf == 0) { printf("RESULT: NOMATCH\n"); return 1; }
  printf("RESULT: OFFSETS %08x-%08x-%08x", id1, id2, cddb);
  for (i = 0; i < nf; i++) printf(" %+d", found[i]);
  printf("\n");
  return 0;
}

int main(int argc, char **argv) {
  Track tr[MAXTRACKS];
  int n = 0, i, a;
  uint32_t start1 = 0;                       /* sector where track 1 starts (non-zero if there is a track00) */
  char why[512];

  if (argc < 2) { fprintf(stderr, "usage: semarv track01.wav track02.wav ...\n       semarv --offset tracks.txt key01.wav ...\n"); return 1; }
  if (!strcmp(argv[1], "--offset")) {
    if (argc < 4) { fprintf(stderr, "usage: semarv --offset tracks.txt key01.wav ...\n"); return 1; }
    return offset_mode(argc, argv);
  }

  for (a = 1; a < argc; a++) {
    const char *base = strrchr(argv[a], '/'); base = base ? base + 1 : argv[a];
    if (!strncmp(base, "track00", 7)) {      /* hidden track: only its length matters */
      Track h = { argv[a], 0, 0, 0, 0, -1 };
      if (open_wav(&h, why, sizeof why)) { printf("RESULT: ERROR %s\n", why); return 1; }
      start1 = h.samples / SAMPLES_PER_SECTOR;
      continue;
    }
    if (n == MAXTRACKS) { printf("RESULT: ERROR more than %d tracks\n", MAXTRACKS); return 1; }
    tr[n].path = argv[a]; tr[n].confidence = -1;
    if (open_wav(&tr[n], why, sizeof why)) { printf("RESULT: ERROR %s\n", why); return 1; }
    n++;
  }
  if (n == 0) { printf("RESULT: ERROR no tracks given\n"); return 1; }

  /* Disc identifiers, from where each track starts on the disc (in sectors) */
  uint32_t offs[MAXTRACKS], leadout, id1 = 0, id2 = 0, cddb_n = 0, cddb;
  uint32_t pos = start1;
  for (i = 0; i < n; i++) {
    if (tr[i].samples % SAMPLES_PER_SECTOR)
      printf("Note: %s is not a whole number of CD sectors long\n", tr[i].path);
    offs[i] = pos;
    pos += tr[i].samples / SAMPLES_PER_SECTOR;
  }
  leadout = pos;
  for (i = 0; i < n; i++) {
    id1 += offs[i];
    id2 += (offs[i] ? offs[i] : 1) * (uint32_t)(i + 1);
    cddb_n += digit_sum((offs[i] + 150) / 75);
  }
  id1 += leadout;
  id2 += leadout * (uint32_t)(n + 1);
  cddb = ((cddb_n % 255) << 24) | ((((leadout + 150) / 75) - ((offs[0] + 150) / 75)) << 8) | (uint32_t)n;

  char url[256];
  snprintf(url, sizeof url, "http://www.accuraterip.com/accuraterip/%x/%x/%x/dBAR-%03d-%08x-%08x-%08x.bin",
           id1 & 0xF, (id1 >> 4) & 0xF, (id1 >> 8) & 0xF, n, id1, id2, cddb);
  printf("Disc: %d tracks, AccurateRip IDs %08x-%08x-%08x\n", n, id1, id2, cddb);

  /* Checksums first: they don't need the network */
  for (i = 0; i < n; i++)
    if (checksum(&tr[i], i == 0, i == n - 1)) { printf("RESULT: ERROR could not read %s\n", tr[i].path); return 1; }

  unsigned char *data = NULL; long len = 0;
  if (fetch_db(url, &data, &len)) return 1;

  /* The entry is a series of pressings: [count][id1][id2][cddb] then per track [confidence][crc][crc450] */
  long p = 0; int pressings = 0;
  while (p + 13 <= len) {
    int cnt = data[p];
    if (cnt != n || rd32(data + p + 1) != id1 || rd32(data + p + 5) != id2 || rd32(data + p + 9) != cddb) break;
    p += 13;
    if (p + 9L * cnt > len) break;
    for (i = 0; i < cnt; i++, p += 9) {
      int conf = data[p];
      uint32_t crc = rd32(data + p + 1);
      if ((crc == tr[i].v1 || crc == tr[i].v2) && conf > tr[i].confidence) tr[i].confidence = conf;
    }
    pressings++;
  }
  free(data);
  if (pressings == 0) { printf("RESULT: NOTINDB\n"); return 1; }

  int matched = 0, lowest = 999999;
  for (i = 0; i < n; i++) {
    if (tr[i].confidence >= 0) {
      printf("Track %02d: accurately ripped (confidence %d)  [v1 %08x, v2 %08x]\n", i + 1, tr[i].confidence, tr[i].v1, tr[i].v2);
      matched++;
      if (tr[i].confidence < lowest) lowest = tr[i].confidence;
    } else {
      printf("Track %02d: NO MATCH in database  [v1 %08x, v2 %08x]\n", i + 1, tr[i].v1, tr[i].v2);
    }
  }
  if (matched == n) { printf("RESULT: MATCH %d\n", lowest); return 0; }
  if (matched > 0) { printf("RESULT: PARTIAL %d/%d\n", matched, n); return 1; }
  printf("RESULT: NOMATCH\n");
  return 1;
}
