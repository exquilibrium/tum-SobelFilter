#include <stdio.h>
#include <stdlib.h>
void cmpIm(unsigned char *d1, unsigned char *d2, int size, unsigned char *out);
int main(int argc, char *args[]) {
    if (argc != 3) {
        printf("Wrong args.\n");
    }

    char *im1 = args[1];
    char *im2 = args[2];

    printf("Image1: %s, Image2: %s\n", im1, im2);

    FILE *file1 = fopen(im1, "rb");
    unsigned char header1[54];

    FILE *file2 = fopen(im2, "rb");
    unsigned char header2[54];

    if (!file1 || !file2) {
        perror("Error opening file\n");
        return 1;
    }

    if (fread(header1, 1, 54, file1) != 54) {
        printf("Not a correct BMP file: file1\n");
        return 1;
    }

    if (fread(header2, 1, 54, file2) != 54) {
        printf("Not a correct BMP file: file2\n");
        return 1;
    }

    int imageSize1 = *(int *) &(header1[0x22]);
    int width1 = *(int *) &(header1[0x12]);
    int height1 = *(int *) &(header1[0x16]);
    if (imageSize1<= 0)
        imageSize1 = width1 * height1 * 3;
    int bpp1 = *(__int16_t *) &(header1[0x1c]);

    int imageSize2 = *(int *) &(header2[0x22]);
    int width2 = *(int *) &(header2[0x12]);
    int height2 = *(int *) &(header2[0x16]);
    if (imageSize2 <= 0)
        imageSize2 = width2 * height2 * 3;
    int bpp2 = *(__int16_t *) &(header2[0x1c]);

    if (width1 <= 0 || height1<= 0) {
        printf("Error in .bmp format1.\n");
        return 1;
    }

    if (width2 <= 0 || height2<= 0) {
        printf("Error in .bmp format2.\n");
        return 1;
    }

    if (bpp1 != 24) {
        printf("Error: Only images with a pixel depth of 24 bpp are accepted. Current pixel depth: %d bpp.\n", bpp1);
        return 1;
    }

    if (bpp2 != 24) {
        printf("Error: Only images with a pixel depth of 24 bpp are accepted. Current pixel depth: %d bpp.\n", bpp2);
        return 1;
    }

    if (width1 - width2) {
        printf("Image widths arent identical. w1=%d, w2=%d.\n", width1, width2);
    }
    if (height1 - height2) {
        printf("Image heights arent identical. h1=%d, h2=%d.\n", height1, height2);
    }
    if (imageSize1 - imageSize2) {
        printf("Image sizes arent identical. s1=%d, s2=%d.\n", imageSize1, imageSize2);
    }
    unsigned char *data1 = malloc(imageSize1);
    fread(data1, 1, imageSize1, file1);
    unsigned char *data2 = malloc(imageSize2);
    fread(data2, 1, imageSize2, file2);
    fclose(file1);
    fclose(file2);
    FILE *out = fopen("imageTest.bmp", "w");
    if (!out) 
	    printf("Error opening output file");
    unsigned char *o = malloc(imageSize2); 
    cmpIm(data1, data2, imageSize1, o);
    fwrite(header2, 1, 54, out);
    fwrite(o, 1, imageSize2, out);
    fclose(out);
}

void cmpIm(unsigned char *d1, unsigned char *d2, int size, unsigned char *out) {
    int oneOff = 0;
    int twoOff = 0;
    int moreOff = 0;
    int greaterTenOff = 0;
    int totDiff = 0;
    for (int i =  1; i < size; i++) {
        int dif = d1[i] - d2[i];
        if (dif < 0) {
            dif *= -1;
        }
	out[i] = dif;
        totDiff += dif;
        if (dif != 0) {
            switch(dif) {
                case 1:
                    oneOff++;
                    break;
                case 2:
                    twoOff++;
                    break;
                default:
                    moreOff++;
                    if (dif > 20)
                        greaterTenOff++;
                    break;
            }
        }
    }
    printf("Images have an average difference of %f.\n", (double) totDiff / (double) size);
    printf("Image has %d bytes with a difference of 1.\n", oneOff);
    printf("Image has %d bytes with a difference of 2.\n", twoOff);
    printf("Image has %d bytes with a difference of more than 2.\n", moreOff);
    printf("Image has %d bytes with a difference of more than 20.\n", greaterTenOff);
}
