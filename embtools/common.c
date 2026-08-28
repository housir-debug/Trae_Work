/*
 * common.c - 公共工具函数实现
 */
#include "embtools.h"

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

int emb_debug = 0;
static int g_color = 1;

void emb_color_autoinit(void)
{
    g_color = isatty(STDOUT_FILENO) ? 1 : 0;
}

int emb_color_enabled(void)
{
    return g_color;
}

int emb_run(const char *argv[], int show)
{
    int rc = -1;
    pid_t pid = fork();
    if (pid < 0) {
        LOGE("fork: %s", strerror(errno));
        return -1;
    }
    if (pid == 0) {
        /* 子进程 */
        if (show) {
            fputs(COL_GRAY "  $ ", stderr);
            for (const char **p = argv; *p; ++p) {
                fputs(*p, stderr);
                fputc(' ', stderr);
            }
            fputs(COL_RESET "\n", stderr);
        }
        execvp(argv[0], (char *const *)argv);
        /* execvp 仅在失败时返回 */
        LOGE("exec %s: %s", argv[0], strerror(errno));
        _exit(127);
    }
    /* 父进程等待 */
    int status = 0;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) {
            LOGE("waitpid: %s", strerror(errno));
            return -1;
        }
    }
    if (WIFEXITED(status))
        rc = WEXITSTATUS(status);
    else
        rc = -1;
    return rc;
}

int emb_which(const char *cmd, char *out, size_t outsz)
{
    const char *path = getenv("PATH");
    if (!path)
        path = "/usr/bin:/bin";

    char *tok, *dup = strdup(path);
    if (!dup)
        return -1;

    int found = 0;
    char tmp[4096];
    for (tok = strtok(dup, ":"); tok; tok = strtok(NULL, ":")) {
        snprintf(tmp, sizeof(tmp), "%s/%s", tok, cmd);
        if (access(tmp, X_OK) == 0) {
            if (out && outsz > 0)
                snprintf(out, outsz, "%s", tmp);
            found = 1;
            break;
        }
    }
    free(dup);
    return found ? 0 : -1;
}

char *emb_read_file(const char *path, size_t *out_len)
{
    FILE *fp = fopen(path, "rb");
    if (!fp)
        return NULL;

    /* 通过 fseek 取大小;但对 /proc/sys 类文件无效,需容错 */
    if (fseek(fp, 0, SEEK_END) == 0) {
        long sz = ftell(fp);
        if (sz > 0) {
            rewind(fp);
            char *buf = malloc(sz + 1);
            if (!buf) { fclose(fp); return NULL; }
            size_t n = fread(buf, 1, sz, fp);
            buf[n] = 0;
            fclose(fp);
            if (out_len) *out_len = n;
            return buf;
        }
    }
    /* 无法 seek,改用动态缓冲读取 */
    rewind(fp);
    size_t cap = 4096, len = 0;
    char *buf = malloc(cap);
    if (!buf) { fclose(fp); return NULL; }
    size_t n;
    while ((n = fread(buf + len, 1, cap - len, fp)) > 0) {
        len += n;
        if (len == cap) {
            cap *= 2;
            char *t = realloc(buf, cap);
            if (!t) { free(buf); fclose(fp); return NULL; }
            buf = t;
        }
    }
    buf[len] = 0;
    fclose(fp);
    if (out_len) *out_len = len;
    return buf;
}

long emb_read_int(const char *path)
{
    char buf[64];
    if (emb_read_str(path, buf, sizeof(buf)) < 0)
        return -1;
    char *end;
    long v = strtol(buf, &end, 0);
    return v;
}

int emb_read_str(const char *path, char *out, size_t outsz)
{
    int fd = open(path, O_RDONLY);
    if (fd < 0)
        return -1;
    ssize_t n = read(fd, out, outsz - 1);
    close(fd);
    if (n <= 0)
        return -1;
    out[n] = 0;
    while (n > 0 && (out[n - 1] == '\n' || out[n - 1] == '\r'))
        out[--n] = 0;
    return 0;
}

int emb_find_in_dir(const char *dir, const char *prefix, const char *suffix,
                    char *out, size_t outsz)
{
    DIR *d = opendir(dir);
    if (!d)
        return -1;
    int found = 0;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (prefix && strncmp(e->d_name, prefix, strlen(prefix)) != 0)
            continue;
        if (suffix) {
            size_t nl = strlen(e->d_name);
            size_t sl = strlen(suffix);
            if (nl <= sl || strcmp(e->d_name + nl - sl, suffix) != 0)
                continue;
        }
        snprintf(out, outsz, "%s/%s", dir, e->d_name);
        found = 1;
        break;
    }
    closedir(d);
    return found ? 0 : -1;
}

void emb_human_size(unsigned long bytes, char *out, size_t outsz)
{
    const char *unit[] = {"B", "K", "M", "G", "T"};
    double v = bytes;
    int i = 0;
    while (v >= 1024 && i < 4) {
        v /= 1024;
        ++i;
    }
    snprintf(out, outsz, "%.2f%s", v, unit[i]);
}

int emb_parse_range(const char *s, int min, int max,
                    int *out, int outsz, int *out_count)
{
    *out_count = 0;
    if (!s)
        return -1;

    if (strcmp(s, "all") == 0) {
        int cnt = max - min + 1;
        if (cnt > outsz) return -1;
        for (int i = 0; i < cnt; ++i)
            out[i] = min + i;
        *out_count = cnt;
        return 0;
    }

    const char *dot = strchr(s, '.');
    if (dot && dot[1] == '.') {
        int a, b;
        if (sscanf(s, "%d..%d", &a, &b) != 2) return -1;
        if (a < min || b > max || a > b) return -1;
        int cnt = b - a + 1;
        if (cnt > outsz) return -1;
        for (int i = 0; i < cnt; ++i) out[i] = a + i;
        *out_count = cnt;
        return 0;
    }

    /* 逗号分隔 */
    char *dup = strdup(s);
    if (!dup) return -1;
    char *tok = strtok(dup, ",");
    while (tok) {
        if (*out_count >= outsz) { free(dup); return -1; }
        out[*out_count] = atoi(tok);
        if (out[*out_count] < min || out[*out_count] > max) {
            free(dup);
            return -1;
        }
        ++(*out_count);
        tok = strtok(NULL, ",");
    }
    free(dup);
    return 0;
}

void emb_usage(void)
{
    fputs(
        COL_BOLD "embtools " COL_RESET COL_CYAN "v" EMBTOOLS_VERSION COL_RESET
        "  - 嵌入式 Linux 工程师助手工具集\n"
        "\n"
        COL_BOLD "用法:" COL_RESET " embtools <command> [options]\n"
        "\n"
        COL_BOLD "可用命令:" COL_RESET "\n"
        "  " COL_GREEN "build" COL_RESET "  交叉编译与构建管理\n"
        "  " COL_GREEN "hw"    COL_RESET "    设备树与硬件调试 (GPIO/I2C/SPI/UART)\n"
        "  " COL_GREEN "sys"   COL_RESET "   系统监控与性能分析\n"
        "  " COL_GREEN "fs"    COL_RESET "    文件系统与部署\n"
        "  " COL_GREEN "help"  COL_RESET "  显示本帮助\n"
        "  " COL_GREEN "-v"    COL_RESET "   显示版本\n"
        "\n"
        "全局选项:\n"
        "  --no-color   关闭彩色输出\n"
        "  -d, --debug  开启调试日志\n"
        "\n"
        "示例:\n"
        "  embtools build toolchain-info arm-linux-gnueabihf-\n"
        "  embtools hw gpio get 17\n"
        "  embtools sys mem\n"
        "  embtools fs ls\n",
        stdout);
}
