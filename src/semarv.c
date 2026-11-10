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
 * Needs nothing but a C compiler to build, and curl at run time. Build a static binary with:
 *   cc -O2 -static -o semarv semarv.c      (Linux)
 *   cc -O2 -o semarv semarv.c              (macOS, which does not allow fully static binaries)
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

int main(int argc, char **argv) {
  Track tr[MAXTRACKS];
  int n = 0, i, a;
  uint32_t start1 = 0;                       /* sector where track 1 starts (non-zero if there is a track00) */
  char why[512];

  if (argc < 2) { fprintf(stderr, "usage: semarv track01.wav track02.wav ...\n"); return 1; }

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

  char url[256], tmp[] = "/tmp/semarvXXXXXX", cmd[512];
  snprintf(url, sizeof url, "http://www.accuraterip.com/accuraterip/%x/%x/%x/dBAR-%03d-%08x-%08x-%08x.bin",
           id1 & 0xF, (id1 >> 4) & 0xF, (id1 >> 8) & 0xF, n, id1, id2, cddb);
  printf("Disc: %d tracks, AccurateRip IDs %08x-%08x-%08x\n", n, id1, id2, cddb);

  /* Checksums first: they don't need the network */
  for (i = 0; i < n; i++)
    if (checksum(&tr[i], i == 0, i == n - 1)) { printf("RESULT: ERROR could not read %s\n", tr[i].path); return 1; }

  /* Fetch the database entry */
  int fd = mkstemp(tmp);
  if (fd < 0) { printf("RESULT: ERROR cannot create a temporary file\n"); return 1; }
  close(fd);
  snprintf(cmd, sizeof cmd, "curl -s -f -m 30 -A 'Semplice' -o '%s' '%s'", tmp, url);
  int rc = system(cmd);
  FILE *db = fopen(tmp, "rb");
  unsigned char *data = NULL; long len = 0;
  if (db) {
    fseek(db, 0, SEEK_END); len = ftell(db); rewind(db);
    if (len > 0 && (data = malloc((size_t)len)) && fread(data, 1, (size_t)len, db) != (size_t)len) len = 0;
    fclose(db);
  }
  remove(tmp);
  if (rc != 0 || len <= 0) {
    /* curl -f fails on HTTP errors: a 404 means the disc simply isn't in the database */
    if (WIFEXITED(rc) && WEXITSTATUS(rc) == 22) { printf("RESULT: NOTINDB\n"); return 1; }
    printf("RESULT: ERROR could not reach the AccurateRip database\n"); return 1;
  }

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
