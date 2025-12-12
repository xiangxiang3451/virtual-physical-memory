#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// 平台相关头文件
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
	printf("\n已分配 128 MiB，按回车键继续...");
	clear_input_buffer();
	getchar();
}

int main(int argc, char* argv[]) {
	if (argc != 2) {
		fprintf(stderr, "用法: %s <r|w>\n", argv[0]);
		fprintf(stderr, "  r - 读取模式（只读不写）\n");
		fprintf(stderr, "  w - 写入模式（会触发缺页中断）\n");
		return 1;
	}

	char mode = argv[1][0];
	if (mode != 'r' && mode != 'w') {
		fprintf(stderr, "错误：参数必须是 'r' 或 'w'\n");
		return 1;
	}

	printf("模式: %s\n", mode == 'r' ? "读取" : "写入");
	printf("页面大小: %d bytes\n", PAGE_SIZE);
	printf("每 128 MiB 暂停一次\n");
	printf("按 Ctrl+C 终止程序\n\n");

	size_t total_allocated = 0;
	size_t chunk_count = 0;

#ifdef _WIN32
	// Windows 的延迟使用 DWORD
	DWORD delay_ms = DELAY_NS / 1000000;
	if (delay_ms == 0) delay_ms = 1;
#else
	// Linux 的 timespec 结构
	struct timespec delay = { 0, DELAY_NS };
#endif

	while (total_allocated < MAX_ALLOC_SIZE) {
		size_t to_allocate = CHUNK_SIZE;
		if (total_allocated + to_allocate > MAX_ALLOC_SIZE) {
			to_allocate = MAX_ALLOC_SIZE - total_allocated;
		}

		printf("正在分配 %zu MiB...", to_allocate / (1024 * 1024));
		fflush(stdout);

		char* memory = (char*)malloc(to_allocate);
		if (memory == NULL) {
			printf("\n内存分配失败！已分配总量: %zu MiB\n",
				total_allocated / (1024 * 1024));
			break;
		}

		total_allocated += to_allocate;
		chunk_count++;
		printf("完成！总计: %zu MiB\n", total_allocated / (1024 * 1024));

		size_t pages = to_allocate / PAGE_SIZE;
		printf("正在访问 %zu 个页面（每页 %d 字节）...\n", pages, PAGE_SIZE);

		for (size_t i = 0; i < pages; i++) {
			char* page_addr = memory + (i * PAGE_SIZE);

			if (mode == 'w') {
				// 写入模式
				page_addr[0] = (char)(i & 0xFF);
			}
			else {
				// 读取模式 - 使用 volatile 防止优化
				volatile char dummy = page_addr[0];
				(void)dummy;
			}

			// 平台特定的延迟
#ifdef _WIN32
			Sleep(delay_ms);
#else
			nanosleep(&delay, NULL);
#endif

			// 显示进度
			if (pages > 10 && i % (pages / 10) == 0 && i > 0) {
				int progress = (int)((i * 100) / pages);
				printf("  进度: %d%%\n", progress);
			}
		}

		// 每分配一次暂停
		printf("\n--- 暂停点 ---\n");
		printf("当前分配总量: %zu MiB\n", total_allocated / (1024 * 1024));
		printf("请检查系统内存使用情况，然后按回车继续...\n");
		wait_for_user();
		printf("继续分配...\n\n");
	}

	printf("\n======= 最终统计 =======\n");
	printf("模式: %s\n", mode == 'r' ? "读取" : "写入");
	printf("总分配内存: %zu MiB\n", total_allocated / (1024 * 1024));
	printf("分配的块数: %zu\n", chunk_count);
	printf("总页数: %zu\n", total_allocated / PAGE_SIZE);

	printf("\n程序将在 30 秒后退出...\n");

	// 保持运行，让用户观察
	for (int i = 30; i > 0; i--) {
		printf("\r剩余时间: %d 秒", i);
		fflush(stdout);
		sleep(1);
	}
	printf("\n程序结束\n");

	return 0;
}