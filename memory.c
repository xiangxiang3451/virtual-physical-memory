#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Platform-specific headers
#ifdef _WIN32
#include <windows.h>
#define sleep(seconds) Sleep((seconds) * 1000)
#define nanosleep(request, remaining) Sleep((request)->tv_nsec / 1000000 + (request)->tv_sec * 1000)
#else
#include <unistd.h>
#include <time.h>
#endif

#define PAGE_SIZE 4096
#define CHUNK_SIZE (128 * 1024 * 1024)
#define DELAY_NS 100000
#define MAX_ALLOC_SIZE (4ULL * 1024 * 1024 * 1024)

void clear_input_buffer() {
	int c;
	while ((c = getchar()) != '\n' && c != EOF);
}

void wait_for_user() {
	printf("\nAllocated 128 MiB, press Enter to continue...");
	clear_input_buffer();
	getchar();
}

int main(int argc, char* argv[]) {
	if (argc != 2) {
		fprintf(stderr, "Usage: %s <r|w>\n", argv[0]);
		fprintf(stderr, "  r - Read mode \n");
		fprintf(stderr, "  w - Write mode \n");
		return 1;
	}

	char mode = argv[1][0];
	if (mode != 'r' && mode != 'w') {
		fprintf(stderr, "Error: Parameter must be 'r' or 'w'\n");
		return 1;
	}

	printf("Mode: %s\n", mode == 'r' ? "Read" : "Write");
	printf("Page size: %d bytes\n", PAGE_SIZE);
	printf("Pause every 128 MiB\n");
	printf("Press Ctrl+C to terminate the program\n\n");

	size_t total_allocated = 0;
	size_t chunk_count = 0;

#ifdef _WIN32
	// Delay for Windows 
	DWORD delay_ms = DELAY_NS / 1000000;
	if (delay_ms == 0) delay_ms = 1;
#else
	// timespec structure for Linux
	struct timespec delay = { 0, DELAY_NS };
#endif

	while (total_allocated < MAX_ALLOC_SIZE) {
		size_t to_allocate = CHUNK_SIZE;
		if (total_allocated + to_allocate > MAX_ALLOC_SIZE) {
			to_allocate = MAX_ALLOC_SIZE - total_allocated;
		}

		printf("Allocating %zu MiB...", to_allocate / (1024 * 1024));
		fflush(stdout);

		char* memory = (char*)malloc(to_allocate);
		if (memory == NULL) {
			printf("\nMemory allocation failed! Total allocated: %zu MiB\n",
				total_allocated / (1024 * 1024));
			break;
		}

		total_allocated += to_allocate;
		chunk_count++;
		printf("Completed! Total: %zu MiB\n", total_allocated / (1024 * 1024));

		size_t pages = to_allocate / PAGE_SIZE;
		printf("Accessing %zu pages (each %d bytes)...\n", pages, PAGE_SIZE);

		for (size_t i = 0; i < pages; i++) {
			char* page_addr = memory + (i * PAGE_SIZE);

			if (mode == 'w') {
				// Write mode
				page_addr[0] = (char)(i & 0xFF);
			}
			else {
				// Read mode 
				volatile char dummy = page_addr[0];
				(void)dummy;
			}

			// Platform-specific delay
#ifdef _WIN32
			Sleep(delay_ms);
#else
			nanosleep(&delay, NULL);
#endif

			if (pages > 10 && i % (pages / 10) == 0 && i > 0) {
				int progress = (int)((i * 100) / pages);
				printf("  Progress: %d%%\n", progress);
			}
		}

		printf("\n--- Pause Point ---\n");
		printf("Current total allocated: %zu MiB\n", total_allocated / (1024 * 1024));
		printf("Please check system memory usage, then press Enter to continue...\n");
		wait_for_user();
		printf("Resuming allocation...\n\n");
	}

	printf("\n======= Final Statistics =======\n");
	printf("Mode: %s\n", mode == 'r' ? "Read" : "Write");
	printf("Total allocated memory: %zu MiB\n", total_allocated / (1024 * 1024));
	printf("Number of allocated chunks: %zu\n", chunk_count);
	printf("Total pages: %zu\n", total_allocated / PAGE_SIZE);

	printf("\nProgram will exit in 30 seconds...\n");

	for (int i = 30; i > 0; i--) {
		printf("\rRemaining time: %d seconds", i);
		fflush(stdout);
		sleep(1);
	}
	printf("\nProgram ended\n");

	return 0;
}