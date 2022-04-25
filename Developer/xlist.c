#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

//XXX #define BUFSIZE 256*1024
#define BUFSIZE 20*1024*1024

#define DUMP 1

#ifdef DUMP
#define DBG(expr) expr;
#else
#define DBG(expr) {} 
#endif

typedef unsigned long tPTS;

int main(int argc, char *argv[])
{
  if (argc != 2) {
     fprintf(stderr, "usage: %s filename\n", argv[0]);
     return 1;
     }

  int f = open(argv[1], O_RDONLY);

  if (f >= 0) {
     unsigned char a[BUFSIZE];
     int s = -1, i = 0, r = 0, offset = 0, total = 0;
     bool I_Frame = false; 
     bool Header = false;
     for (;;) {
         if (r < BUFSIZ / 2 || i > BUFSIZ / 2) {
            if (r > 0) {
               r -= i;
               memmove(a, a + i, r);
               }
            int b = read(f, a + r, sizeof(a) - r);
            if (b <= 0) {
               if (b < 0)
                  fprintf(stderr, "%s: %s\n", argv[1], strerror(errno));
               break;
               }
            total += b;
            r += b;
            offset += i;
            i = 0;
            }
         for (; i < r; i++) {
             if (a[i] == 0 && a[i + 1] == 0 && a[i + 2] == 1) {
                DBG(printf("%8d %02X", offset + i, a[i + 3]));
                switch (a[i + 3]) {
                  case 0x00: // picture_start_code
                             {
                               unsigned short m = ntohs(*(short *)&a[i + 4]);
                               DBG(printf(" picture_header - temporal_reference: %4d  picture_coding_type: %d", m >> 6, (m >> 3) & 0x07));
                             }
                             break;
                  case 0xB2: // user_data_start_code
                             {
                               DBG(printf(" user_data_start"));
                             }
                             break;
                  case 0xB3: // sequence_header_code
                             {
                               DBG(printf(" sequence_header"));
                             }
                             break;
                  case 0xB5: // extension_start_code
                             {
                               DBG(printf(" extension_start"));
                             }
                             break;
                  case 0xB7: // sequence_end_code
                             {
                               DBG(printf(" sequence_end"));
                             }
                             break;
                  case 0xB8: // group_start_code
                             {
                               unsigned long m = ntohl(*(long *)&a[i + 4]);
                               DBG(printf(" group_of_pictures_header - time_code: %02d:%02d:%02d.%02d closed_gop: %d broken_link: %d", (m >> 26) & 0x1F, (m >> 20) & 0x3F, (m >> 13) & 0x3F, (m >> 7) & 0x3F, (m >> 6) & 0x01, (m >> 5) & 0x01));
                             }
                             break;
                  case 0xBA: // packet header
                             {
                               Header = true;
                               I_Frame = false;
                               s = i;
                               DBG(printf(" pack header"));
                               for (int j = 0; j < 10; j++)
                                   printf(" %02X", a[i + 4 + j]);
                               i += 10 - 1;
                             }
                             break;
                  case 0xBB: // system header
                             {
                               DBG(printf(" system header"));
                               int n = a[i + 4] * 256 + a[i + 5] + 2;
                               printf(" %3d", n);
                               for (int j = 0; j < n; j++)
                                   printf(" %02X", a[i + 4 + j]);
                               i += n - 1;
                             }
                             break;
                  case 0xBD: // dolby digital
                             {
                               static tPTS lastPts = 0;
                               DBG(printf(" dolby"));
                               int n = a[i + 4] * 256 + a[i + 5];
                               printf(" %5d", n);
                               int h = 5 + a[i + 8];
                               for (int j = 0; j < h; j++)
                                   printf(" %02X", a[i + 4 + j]);
                               i += 8; // the minimum length of the dolby packet header
                               if (a[i] >= 5) {
                                  tPTS pts;
                                  pts  = (((tPTS)a[i + 1]) & 0x06) << 29; 
                                  pts |= ( (tPTS)a[i + 2])         << 22;
                                  pts |= (((tPTS)a[i + 3]) & 0xFE) << 14;
                                  pts |= ( (tPTS)a[i + 4])         <<  7;      
                                  pts |= (((tPTS)a[i + 5]) & 0xFE) >>  1;
                                  printf(" pts: %u          %u", pts, pts - lastPts);
                                  lastPts = pts;
                                  }
                               i += n - 1 - 8;
                             }
                             break;
                  case 0xC0 ... 0xDF: // audio
                             {
                               static tPTS lastPts = 0;
                               DBG(printf(" audio"));
                               int n = a[i + 4] * 256 + a[i + 5];
                               printf(" %5d", n);
                               int h = 5 + a[i + 8];
                               for (int j = 0; j < h; j++)
                                   printf(" %02X", a[i + 4 + j]);
                               i += 8; // the minimum length of the audio packet header
                               if (a[i] >= 5) {
                                  tPTS pts;
                                  pts  = (((tPTS)a[i + 1]) & 0x06) << 29; 
                                  pts |= ( (tPTS)a[i + 2])         << 22;
                                  pts |= (((tPTS)a[i + 3]) & 0xFE) << 14;
                                  pts |= ( (tPTS)a[i + 4])         <<  7;      
                                  pts |= (((tPTS)a[i + 5]) & 0xFE) >>  1;
                                  printf(" pts: %u          %u", pts, pts - lastPts);
                                  lastPts = pts;
                                  }
                               i += n - 1 - 8;
                             }
                             break;
                  case 0xE0 ... 0xEF: // video
                             {
                               static tPTS lastPts = 0;
                               DBG(printf(" video"));
                               int n = a[i + 4] * 256 + a[i + 5];
                               printf(" %5d", n);
                               int h = 5 + a[i + 8];
                               for (int j = 0; j < h; j++)
                                   printf(" %02X", a[i + 4 + j]);
                               i += 8; // the minimum length of the video packet header
                               if (a[i] >= 5) {
                                  tPTS pts;
                                  pts  = (((tPTS)a[i + 1]) & 0x06) << 29; 
                                  pts |= ( (tPTS)a[i + 2])         << 22;
                                  pts |= (((tPTS)a[i + 3]) & 0xFE) << 14;
                                  pts |= ( (tPTS)a[i + 4])         <<  7;      
                                  pts |= (((tPTS)a[i + 5]) & 0xFE) >>  1;
                                  printf(" pts: %u          %u", pts, pts - lastPts);
                                  lastPts = pts;
                                  }
                               i += a[i];   // possible additional header bytes
                             }
                             break;
                  default:   {
#ifdef DUMP
                               if (0x01 <= a[i + 3] && a[i + 3] <= 0xAF)
                                  printf(" slice");
                               for (int j = 0; j < 20; j++)
                                   printf(" %02X", a[i + 4 + j]);
#endif //DUMP
                             }
                  }
                DBG(printf("\n"));
                if (a[i + 3] == 0) {
                   int PictureType = (a[i + 5] >> 3) & 0x07;
                   I_Frame = PictureType == 1;
                   if (!I_Frame)
                      s = -1;
                   }
                }
#ifndef DUMP
             if (s >= 0 && Header && I_Frame) {
                for (int j = s; j < i; j++)
                    printf("%c", a[j]);
                s = -1;
                }
             if (I_Frame)
                printf("%c", a[i]);
#endif //DUMP
             }
         }
     }
  else
     fprintf(stderr, "%s: %s\n", argv[1], strerror(errno));
  return 0;
}
