#include <stdio.h>
#include <stdint.h>

// |    |    |    |    |    |    |    |    |
// 0000011111222223333344444555556666677777
// 0123456701234567012345670123456701234567
// 0123401234012340123401234012340123401234
// 0123456789012345678901234567890123456789
//         |       |       |       |       |
//
// Port from http://golang.org/pkg/encoding/base32/
void
ngx_txid_base32_encode(unsigned char *dst, unsigned char *src, size_t len) {
    const char *tbl = "0123456789abcdefghijklmnopqrstuv";

    while (len > 0) {
        dst[0] = 0;
        dst[1] = 0;
        dst[2] = 0;
        dst[3] = 0;
        dst[4] = 0;
        dst[5] = 0;
        dst[6] = 0;
        dst[7] = 0;

        switch (len) {
        default:
            dst[7] |= src[4] & 0x1F;
            dst[6] |= src[4] >> 5;
        case 4:
            dst[6] |= (src[3] << 3) & 0x1F;
            dst[5] |= (src[3] >> 2) & 0x1F;
            dst[4] |= src[3] >> 7;
        case 3:
            dst[4] |= (src[2] << 1) & 0x1F;
            dst[3] |= (src[2] >> 4) & 0x1F;
        case 2:
            dst[3] |= (src[1] << 4) & 0x1F;
            dst[2] |= (src[1] >> 1) & 0x1F;
            dst[1] |= (src[1] >> 6) & 0x1F;
        case 1:
            dst[1] |= (src[0] << 2) & 0x1F;
            dst[0] |= src[0] >> 3;
        }

        int j;
        for (j = 0; j < 8; j++) {
            dst[j] = tbl[dst[j]];
        }

        if (len < 5) {
            dst[7] = '=';
            if (len < 4) {
                dst[6] = '=';
                dst[5] = '=';
                if (len < 3) {
                    dst[4] = '=';
                    if (len < 2) {
                        dst[3] = '=';
                        dst[2] = '=';
                    }
                }
            }
            break;
        }

        len -= 5;
        src += 5;
        dst += 8;
    }
}

size_t
ngx_txid_base32_encode_len(size_t len) {
    return (len + 4) / 5 * 8;
}
