/*
 * embtools.h - Embedded Linux Engineer Assistant
 *
 * 一款面向嵌入式 Linux 软件工程师的命令行综合工具集,涵盖:
 *   - build : 交叉编译与构建管理
 *   - hw    : 设备树与硬件调试 (GPIO/I2C/SPI/UART/Regmap)
 *   - sys   : 系统监控与性能分析
 *   - fs    : 文件系统与部署
 *
 * 该头文件定义各子命令模块共享的类型、宏与公共工具函数。
 */
#ifndef EMBTOOLS_H
#define EMBTOOLS_H

#include <stddef.h>
#include <stdio.h>

#define EMBTOOLS_NAME    "embtools"
#define EMBTOOLS_VERSION "1.0.0"

/* ANSI 颜色码,便于在终端中突出显示 */
#define COL_RESET   "\033[0m"
#define COL_RED     "\033[31m"
#define COL_GREEN   "\033[32m"
#define COL_YELLOW  "\033[33m"
#define COL_BLUE    "\033[34m"
#define COL_CYAN    "\033[36m"
#define COL_GRAY    "\033[90m"
#define COL_BOLD    "\033[1m"

/* 跟随 stdin 是否为 TTY 自动关闭颜色,默认开启 */
void emb_color_autoinit(void);
int  emb_color_enabled(void);

/* 日志输出宏:错误/警告/信息/调试 */
#define LOGE(fmt, ...) \
    fprintf(stderr, COL_RED "[E] " COL_RESET fmt "\n", ##__VA_ARGS__)
#define LOGW(fmt, ...) \
    fprintf(stderr, COL_YELLOW "[W] " COL_RESET fmt "\n", ##__VA_ARGS__)
#define LOGI(fmt, ...) \
    fprintf(stdout, COL_GREEN "[I] " COL_RESET fmt "\n", ##__VA_ARGS__)
#define LOGD(fmt, ...) \
    do { if (emb_debug) fprintf(stderr, COL_GRAY "[D] " fmt COL_RESET "\n", ##__VA_ARGS__); } while (0)

/* 全局调试开关,由 main 设置 */
extern int emb_debug;

/* 子命令函数原型:接收与 main 一致的参数 */
typedef int (*emb_subcmd_fn)(int argc, char **argv);

/* 子命令描述表项 */
typedef struct {
    const char       *name;     /* 子命令名 */
    const char       *summary;  /* 一行简介 */
    const char       *help;     /* 详细帮助文本 */
    emb_subcmd_fn     handler;  /* 处理函数 */
} emb_subcmd_t;

/* 全局子命令表(在 main.c 中定义) */
extern const emb_subcmd_t emb_subcmds[];

/* 各功能模块的处理函数 */
int cmd_build(int argc, char **argv);
int cmd_hw(int argc, char **argv);
int cmd_sys(int argc, char **argv);
int cmd_fs(int argc, char **argv);

/* ---------- 公共工具函数 ---------- */

/* 安全执行外部命令,返回退出码;show 控制是否回显命令 */
int emb_run(const char *argv[], int show);

/* 在 PATH 中查找可执行文件,找到返回 0 并填充路径 */
int emb_which(const char *cmd, char *out, size_t outsz);

/* 读取整个文件到堆缓冲,调用者负责 free;失败返回 NULL */
char *emb_read_file(const char *path, size_t *out_len);

/* 读取 /sys/ 或 /proc/ 中一个键值对文件首行整数 */
long emb_read_int(const char *path);

/* 读取一个 sysfs 字符串(去掉尾部换行) */
int emb_read_str(const char *path, char *out, size_t outsz);

/* 在路径上定位具有指定扩展名/前缀的文件 */
int emb_find_in_dir(const char *dir, const char *prefix, const char *suffix,
                    char *out, size_t outsz);

/* 把数值按人类可读方式打印 (KB/MB/GB) */
void emb_human_size(unsigned long bytes, char *out, size_t outsz);

/* 解析 "n", "n..m", "all" 形式的范围参数 */
int emb_parse_range(const char *s, int min, int max,
                    int *out, int outsz, int *out_count);

/* 打印主帮助 */
void emb_usage(void);

#endif /* EMBTOOLS_H */
