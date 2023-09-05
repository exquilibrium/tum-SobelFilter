#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <math.h>
#include <string.h>

double v_sobel[] = {1, 2, 1, 0, 0, 0, -1, -2, -1};
double h_sobel[] = {1, 0, -1, 2, 0, -2, 1, 0, -1};

extern void filter_asm(unsigned char *data, unsigned char *result, int w, int h);
extern void filter_asm_simd(unsigned char *data, unsigned char *result, int w, int h);
extern void filter_asm_ext(unsigned char *data, unsigned char *result, int w, int h);
extern void filter_asm_simd_ext(unsigned char *data, unsigned char *result, int w, int h);
void filter(unsigned char *data, unsigned char *result, int w, int h);
void filter_opt(unsigned char *data, unsigned char *result, int w, int h);
void filter_ext(unsigned char *data, unsigned char *result, int w, int h);
void filter_opt_ext(unsigned char *data, unsigned char *result, int w, int h);

double handle(unsigned char *data, int pos, int w);
double handle_opt(unsigned char *data, int pos, int w);

static inline double curtime(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

void printHelp() {
	printf("==============================help==============================\n");
	printf("-h/--help: print help and quit program.\n");
	printf("-c: run C implementation.\n");
	printf("-i: run C implementation with optimized Sobel operator.\n");
	printf("-a: run Assembly implementation.\n");
	printf("-s: run Assembly implementation with SIMD.\n");
	printf("-n: use no padding for edge cases and skip outer pixel on each side.\n");
	printf("-m: use mirrored padding for edge cases for the outer pixel.\n");
	printf("-f <path>: set input file. Default: lena.bmp\n");
	printf("-o <path>: set output file. Default: lenaRes.bmp\n");
	printf("default: run all implementations. Mirrored padding is used.\n");
	printf("Multiple parameters can be set! Benchmarks are always done!\n");
	printf("================================================================\n");
}

int main(int argc, char *arg[]) {
    int cFlag = 1;
    int aFlag = 1;
    int c_oFlag = 1;
    int a_oFlag = 1;
    int mFlag = 1;
    int sFlag = 1;
    char *input = "lena.bmp";
    char *output = "lenaRes.bmp";

    if (argc > 1) {
        cFlag = 0;
        aFlag = 0;
        c_oFlag = 0;
        a_oFlag = 0;
        mFlag = 0;
        sFlag = 0;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(arg[i], "-c")) {
                cFlag = 1;
                continue;
            }

            if (!strcmp(arg[i], "-a")) {
                aFlag = 1;
                continue;
            }

            if (!strcmp(arg[i], "-i")) {
                c_oFlag = 1;
                continue;
            }

            if (!strcmp(arg[i], "-s")) {
                a_oFlag = 1;
                continue;
            }

            if (!strcmp(arg[i], "-m")) {
                mFlag = 1;
                continue;
            }

            if (!strcmp(arg[i], "-n")) {
                sFlag = 1;
                continue;
            }

	    if (!strcmp(arg[i], "-h") || !strcmp(arg[i], "--help")) {
		printHelp();
            	return 0;
	    }

	    if (!strcmp(arg[i], "-f")) {
		    i++;
		    if (i >= argc) {
			    printf("Error on parameter -f. Use parameter -h or --help to print information on all parameters\n");
			    continue;
		    }
		    input = arg[i];
		    continue;
	    }

	    if (!strcmp(arg[i], "-o")) {
		    i++;
		    if (i >= argc) {
			    printf("Error on parameter -o. Use parameter -h or --help to print information on all parameters.\n");
			    continue;
		    }
		    output = arg[i];
		    continue;
	    }

	    printf("Unknown parameter %s. Use parameter -h or --help to print information on all parameters.\n", arg[i]);
        }
    }

    if (!(sFlag + mFlag)) {
        mFlag = 1;
	sFlag = 1;
    }

    if (!(aFlag + cFlag + a_oFlag + c_oFlag)) {
	    aFlag = 1;
	    cFlag = 1;
	    a_oFlag = 1;
	    c_oFlag = 1;
    }

    FILE *file = fopen(input, "rb");
    unsigned char header[54];

    if (!file) {
        perror("Error opening file\n");
	return 1;
    }

    if (fread(header, 1, 54, file) != 54) {
        printf("Not a correct BMP file\n");
        return 1;
    }

    if (header[0] != 'B' || header[1] != 'M') {
        printf("Not a correct BMP file\n");
        return 1;
    }

    int imageSize = *(int *) &(header[0x22]);
    int width = *(int *) &(header[0x12]);
    int height = *(int *) &(header[0x16]);
    if (imageSize <= 0)
        imageSize = width * height * 3;
    int bpp = *(__int16_t *) &(header[0x1c]);

    if (bpp != 24) {
        printf("Error: Only images with a pixel depth of 24 bpp are accepted. Current pixel depth: %d bpp.\n", bpp);
        return 1;
    }
    if (width <= 0 || height <= 0) {
	    printf("Error in .bmp format.\n");
	    return 1;
    }
    unsigned char *data = malloc(imageSize);
    unsigned char *data_ext = malloc(imageSize + 6 * (width + height+2));
    unsigned char *result = malloc(imageSize);
    unsigned char *result_ext = malloc(imageSize + 6 * (width + height+2));
    memset(result, 0, imageSize);
    fread(data, 1, imageSize, file);
    for (int i = 0; i < height; i++) {
        memcpy(data_ext + (i + 1) * (width * 3 + 6) + 3, data + i * width * 3, width * 3);
    }
    fclose(file);
    if (sFlag) {
        printf("Runs with skipped edge pixels:\n");
        if (cFlag) {
            double start = curtime();
            filter(data, result, width, height);
            double end = curtime();
            printf("C implementation took %f seconds.\n", end - start);
        }

        if (c_oFlag) {
            double start = curtime();
            filter_opt(data, result, width, height);
            double end = curtime();
            printf("C implementation with optimized Sobel operator took %f seconds.\n", end - start);
        }

        if (aFlag) {
            double start = curtime();
            filter_asm(data, result, width, height);
            double end = curtime();
            printf("Assembly implementation took %f seconds.\n", end - start);
        }

        if (a_oFlag) {
            double start = curtime();
            filter_asm_simd(data, result, width, height);
            double end = curtime();
            printf("Assembly implementation with SIMD took %f seconds.\n", end - start);
        }
        printf("\n");
    }
    if (mFlag) {
        printf("Runs with mirrored padding:\n");
        if (cFlag) {
            double start = curtime();
            filter_ext(data_ext, result_ext, width + 2, height + 2);
            double end = curtime();
            printf("C implementation took %f seconds.\n", end - start);
        }

        if (c_oFlag) {
            double start = curtime();
            filter_opt_ext(data_ext, result_ext, width + 2, height + 2);
            double end = curtime();
            printf("C implementation with optimized Sobel operator took %f seconds.\n", end - start);
        }

        if (aFlag) {
            double start = curtime();
            filter_asm_ext(data_ext, result_ext, width + 2, height + 2);
            double end = curtime();
            printf("Assembly implementation took %f seconds.\n", end - start);
        }

        if (a_oFlag) {
            double start = curtime();
            filter_asm_simd_ext(data_ext, result_ext, width + 2, height + 2);
            double end = curtime();
            printf("Assembly implementation with SIMD took %f seconds.\n", end - start);
        }
        printf("\n");
    }

    FILE *f = fopen(output, "w");
    if (!f)
        perror("error opening output file");
    fwrite(header, 1, 54, f);
    if (!mFlag) {
        fwrite(result, 1, imageSize, f);
    } else {
        for (int i = 0; i < height; i++) {
            fwrite(result_ext + (i + 1) * (width * 3 + 6) + 3, 1, 3 * width, f);
        }
    }
    fclose(f);
    free(data);
    free(result);
    free(data_ext);
    free(result_ext);
    return 0;
}

void filter(unsigned char *data, unsigned char *result, int w, int h) {
    for (int y = 1; y < (h - 1); y++) {
        for (int x = 3; x < 3 * (w - 1); x++) {
	        int pos = x + y * 3 * w;
            double val = handle(data, pos, w);
            if (val > 255)
                val = 255;
            result[pos] = val;
        }
    }
}

double handle(unsigned char *data, int pos, int w) {
    double resV = 0;
    double resH = 0;
    for (int i = -1; i < 2; i++) {
        for (int j = -1; j < 2; j++) {
            double sV = v_sobel[i + 1 + 3 * (j + 1)];
            double d = data[pos + 3 * i + 3 * w * j];
            double sH = h_sobel[i + 1 + 3 * (j + 1)];
            resV += sV * d;
            resH += sH * d;
        }
    }
    return sqrt(resV * resV + resH * resH);
}

void filter_opt(unsigned char *data, unsigned char *result, int w, int h) {
	for (int y = 1; y < (h - 1); y++) {
		for (int x = 3; x < 3 * (w - 1); x++) {
                    int pos = x + y * 3 * w;
            		double val = handle_opt(data, pos, w);
            		if (val > 255)
            		    val = 255;
            		result[pos] = val;
	       	}
       	}
}

double handle_opt(unsigned char *data, int pos, int w) {
	double resH = data[pos - 3 * w - 3] + 2 * data[pos - 3 * w] + data[pos - 3 * w + 3]
	       	- data[pos + 3 * w - 3] - 2 * data[pos + 3 * w] - data[pos + 3 * w + 3];
	double resV = data[pos - 3 * w - 3] - data[pos - 3 * w + 3] + 2 * data[pos - 3]
	       	- 2 * data[pos + 3] + data[pos + 3 * w - 3] - data[pos + 3 * w + 3];
	return sqrt(resV * resV + resH * resH);
}

void prepEdges(unsigned char *data, int w, int h) {
    for (int i = 1; i < (w - 1) * 3; i++) {
        data[i] = data[i + w * 3];
        data[i + (h - 1) * w * 3] = data[i + (h - 2) * w * 3];
    }

    for (int i = 0; i < h; i++) {
        for (int j = 0; j < 3; j++) {
            data[i * w * 3 + j] = data[i * w * 3 + 3 + j];
            data[i * w * 3 + (w - 1) * 3 + j] = data[i * w * 3 + (w - 1) * 3 + j - 3];
        }
    }
}

void filter_ext(unsigned char *data, unsigned char *result, int w, int h) {
    prepEdges(data, w, h);
    filter(data, result, w, h);
}
void filter_opt_ext(unsigned char *data, unsigned char *result, int w, int h) {
    prepEdges(data, w, h);
    filter_opt(data, result, w, h);
}
