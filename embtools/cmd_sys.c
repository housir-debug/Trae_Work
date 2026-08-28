/*
 * cmd_sys.c - 系统监控与性能分析
 *
 * 子命令:
 *   cpu                - 显示 CPU 使用率与平均负载
 *   mem                - 显示内存/swap 使用
 *   disk               - 显示磁盘 IO
 *   net                - 显示网络接口与统计
 *   ps [pattern]       - 列出进程(可选过滤)
 *   top N [field]      - 显示 top N 进程(cpu/mem)
 *   log [N]            - dmesg/journalctl
 *   perf record CMD    - perf 录制
 *   perf report [FILE] - perf 报告
 *   trace EVENT        - ftrace 跟踪
 *   uptime             - 系统运行时间
 *   temp               - 各 hwmon 温度
 */
#include "embtools.h"

#include <dirent.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysinfo.h>
#include <time.h>
#include <unistd.h>

/* 从 /proc/stat 读取 CPU 总体使用率(自启动以来的累计) */
static int read_cpu_jiffies(unsigned long *idle, unsigned long *total)
{
    FILE *fp = fopen("/proc/stat", "r");
    if (!fp)
        return -1;
    char line[256];
    if (!fgets(line, sizeof(line), fp)) {
        fclose(fp);
        return -1;
    }
    fclose(fp);

    unsigned long user, nice, sys, irq, softirq, steal;
    unsigned long iowait;
    /* cpu  user nice system idle iowait irq softirq steal ...
     * 总和 - idle = busy
     */
    if (sscanf(line, "cpu %lu %lu %lu %lu %lu %lu %lu %lu",
               &user, &nice, &sys, idle, &iowait, &irq, &softirq, &steal) < 4)
        return -1;
    /* idle 包含 iowait,我们按常见算法:总 = 全部之和 */
    *total = user + nice + sys + *idle + iowait + irq + softirq + steal;
    /* 真正空闲 = idle + iowait */
    *idle = *idle + iowait;
    return 0;
}

static int sub_cpu(int argc, char **argv)
{
    (void)argc; (void)argv;

    unsigned long idle1, total1, idle2, total2;
    if (read_cpu_jiffies(&idle1, &total1) < 0) {
        LOGE("无法读取 /proc/stat");
        return 1;
    }
    /* 等待 1 秒 */
    sleep(1);
    if (read_cpu_jiffies(&idle2, &total2) < 0) {
        LOGE("无法读取 /proc/stat");
        return 1;
    }
    unsigned long dtot = total2 - total1;
    unsigned long didle = idle2 - idle1;
    double busy = dtot > 0 ? (1.0 - (double)didle / (double)dtot) * 100.0 : 0.0;

    printf(COL_BOLD "CPU 使用率" COL_RESET " (1s 采样): %.1f%%\n", busy);

    /* 平均负载 */
    struct sysinfo si;
    if (sysinfo(&si) == 0) {
        double sc = 1.0 / (1 << SI_LOAD_SHIFT);
        printf(COL_BOLD "Load avg" COL_RESET "   : %.2f %.2f %.2f\n",
               si.loads[0] * sc, si.loads[1] * sc, si.loads[2] * sc);
        printf(COL_BOLD "Uptime" COL_RESET "     : %ld 秒 (%.2f 天)\n",
               si.uptime, si.uptime / 86400.0);
    }

    /* CPU 在线数 + /proc/cpuinfo 摘要 */
    long online = sysconf(_SC_NPROCESSORS_ONLN);
    long config = sysconf(_SC_NPROCESSORS_CONF);
    printf(COL_BOLD "CPU" COL_RESET "       : %ld 在线 / %ld 配置\n",
           online, config);

    /* 每个 CPU 的频率 */
    for (long i = 0; i < online; ++i) {
        char path[128];
        snprintf(path, sizeof(path),
                 "/sys/devices/system/cpu/cpu%ld/cpufreq/scaling_cur_freq", i);
        long khz = emb_read_int(path);
        if (khz >= 0)
            printf("  cpu%-2ld : %ld MHz\n", i, khz / 1000);
        else
            printf("  cpu%-2ld : N/A\n", i);
    }
    return 0;
}

static int sub_mem(int argc, char **argv)
{
    (void)argc; (void)argv;
    FILE *fp = fopen("/proc/meminfo", "r");
    if (!fp) {
        LOGE("open /proc/meminfo: %s", strerror(errno));
        return 1;
    }
    char line[256];
    unsigned long total = 0, free = 0, avail = 0, buf = 0, cache = 0, swap_total = 0, swap_free = 0;
    while (fgets(line, sizeof(line), fp)) {
        char key[64];
        unsigned long v;
        if (sscanf(line, "%63s %lu", key, &v) != 2)
            continue;
        if (strcmp(key, "MemTotal:") == 0)         total = v;
        else if (strcmp(key, "MemFree:") == 0)      free = v;
        else if (strcmp(key, "MemAvailable:") == 0) avail = v;
        else if (strcmp(key, "Buffers:") == 0)     buf = v;
        else if (strcmp(key, "Cached:") == 0)       cache = v;
        else if (strcmp(key, "SwapTotal:") == 0)    swap_total = v;
        else if (strcmp(key, "SwapFree:") == 0)     swap_free = v;
    }
    fclose(fp);

    char hs[16];
    printf(COL_BOLD "内存" COL_RESET ":\n");
    emb_human_size(total * 1024UL, hs, sizeof(hs));
    printf("  Total      : %lu KB (%s)\n", total, hs);
    emb_human_size(free * 1024UL, hs, sizeof(hs));
    printf("  Free       : %lu KB (%s)\n", free, hs);
    emb_human_size(avail * 1024UL, hs, sizeof(hs));
    printf("  Available  : %lu KB (%s)\n", avail, hs);
    emb_human_size(buf * 1024UL, hs, sizeof(hs));
    printf("  Buffers    : %lu KB (%s)\n", buf, hs);
    emb_human_size(cache * 1024UL, hs, sizeof(hs));
    printf("  Cached     : %lu KB (%s)\n", cache, hs);
    if (swap_total > 0) {
        emb_human_size(swap_total * 1024UL, hs, sizeof(hs));
        printf(COL_BOLD "Swap" COL_RESET ":\n");
        printf("  Total      : %lu KB (%s)\n", swap_total, hs);
        emb_human_size(swap_free * 1024UL, hs, sizeof(hs));
        printf("  Free       : %lu KB (%s)\n", swap_free, hs);
    } else {
        printf(COL_BOLD "Swap" COL_RESET ": (none)\n");
    }
    return 0;
}

static int sub_disk(int argc, char **argv)
{
    (void)argc; (void)argv;
    /* 1) /proc/diskstats 读取每盘读写 */
    FILE *fp = fopen("/proc/diskstats", "r");
    if (!fp) {
        LOGE("open /proc/diskstats: %s", strerror(errno));
        return 1;
    }
    printf(COL_BOLD "%-12s %-10s %-14s %-14s\n" COL_RESET,
           "DEVICE", "MAJ:MIN", "READ_SECT", "WRITE_SECT");
    char line[512];
    while (fgets(line, sizeof(line), fp)) {
        int maj, min;
        char dev[64];
        /* field 4 = reads completed, field 4+1 = reads merged... 我们需要
         * sector read = field 6 (sector read), field 10 (sector write) */
        unsigned long rd_sect = 0, wr_sect = 0;
        /* 解析:把整行用 strtok 取字段 */
        char *tok;
        char *save = NULL;
        tok = strtok_r(line, " \t\n", &save);
        char fields[32][32];
        int nf = 0;
        while (tok && nf < 32) {
            strncpy(fields[nf++], tok, sizeof(fields[0]) - 1);
            tok = strtok_r(NULL, " \t\n", &save);
        }
        if (nf < 14)
            continue;
        maj = atoi(fields[0]);
        min = atoi(fields[1]);
        snprintf(dev, sizeof(dev), "%s", fields[2]);
        rd_sect = strtoul(fields[5], NULL, 10);
        wr_sect = strtoul(fields[9], NULL, 10);
        /* 仅显示非分区(主设备) - 通过 maj>=8 等过滤 */
        printf("%-12s %d:%-7d %-14lu %-14lu\n", dev, maj, min, rd_sect, wr_sect);
    }
    fclose(fp);

    /* 2) df 概览 */
    printf("\n" COL_BOLD "挂载点使用" COL_RESET ":\n");
    const char *df[] = { "df", "-hP", NULL };
    return emb_run(df, 1);
}

static int sub_net(int argc, char **argv)
{
    (void)argc; (void)argv;
    /* 列出 /sys/class/net/ 接口 + 读取 statistics */
    DIR *d = opendir("/sys/class/net");
    if (!d) {
        LOGE("open /sys/class/net: %s", strerror(errno));
        return 1;
    }
    printf(COL_BOLD "%-10s %-18s %-14s %-14s %-8s\n" COL_RESET,
           "IFACE", "MAC", "RX_BYTES", "TX_BYTES", "STATE");
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] == '.')
            continue;
        char p[256];
        char mac[32] = "?";
        snprintf(p, sizeof(p), "/sys/class/net/%s/address", e->d_name);
        emb_read_str(p, mac, sizeof(mac));
        long rx = -1, tx = -1;
        snprintf(p, sizeof(p), "/sys/class/net/%s/statistics/rx_bytes",
                 e->d_name);
        rx = emb_read_int(p);
        snprintf(p, sizeof(p), "/sys/class/net/%s/statistics/tx_bytes",
                 e->d_name);
        tx = emb_read_int(p);
        snprintf(p, sizeof(p), "/sys/class/net/%s/operstate", e->d_name);
        char st[16] = "?";
        emb_read_str(p, st, sizeof(st));
        char rxs[16], txs[16];
        emb_human_size(rx < 0 ? 0 : (unsigned long)rx, rxs, sizeof(rxs));
        emb_human_size(tx < 0 ? 0 : (unsigned long)tx, txs, sizeof(txs));
        printf("%-10s %-18s %-14s %-14s %-8s\n",
               e->d_name, mac, rxs, txs, st);
    }
    closedir(d);
    return 0;
}

static int sub_ps(int argc, char **argv)
{
    const char *pattern = (argc >= 3) ? argv[2] : NULL;
    DIR *d = opendir("/proc");
    if (!d) {
        LOGE("open /proc: %s", strerror(errno));
        return 1;
    }
    printf(COL_BOLD "%-8s %-8s %-8s %-8s %s\n" COL_RESET,
           "PID", "PPID", "RSS(KB)", "STATE", "CMD");
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        char *end;
        long pid = strtol(e->d_name, &end, 10);
        if (*end != 0 || pid <= 0)
            continue;
        char path[256];
        /* /proc/PID/stat: fields: pid (comm) state ppid ... rss is field 24 */
        snprintf(path, sizeof(path), "/proc/%ld/stat", pid);
        char *stat = emb_read_file(path, NULL);
        if (!stat)
            continue;
        /* 解析 stat: comm 在括号内,需小心处理 */
        char *comm_s = strchr(stat, '(');
        char *comm_e = strrchr(stat, ')');
        if (!comm_s || !comm_e || comm_e < comm_s) {
            free(stat);
            continue;
        }
        char comm[256];
        size_t cl = comm_e - comm_s - 1;
        if (cl >= sizeof(comm)) cl = sizeof(comm) - 1;
        memcpy(comm, comm_s + 1, cl);
        comm[cl] = 0;
        /* 从 comm_e+2 开始按空格分隔 */
        char *rest = comm_e + 2;
        char state = ' ';
        long ppid = 0;
        long rss = 0;
        int fi = 3; /* state is field 3 */
        char *save = NULL;
        char *t = strtok_r(rest, " ", &save);
        while (t) {
            if (fi == 3) state = t[0];
            else if (fi == 4) ppid = atol(t);
            else if (fi == 24) rss = atol(t);
            t = strtok_r(NULL, " ", &save);
            ++fi;
        }
        free(stat);
        /* 命令行 */
        snprintf(path, sizeof(path), "/proc/%ld/cmdline", pid);
        char *cmdline = emb_read_file(path, NULL);
        if (cmdline && cmdline[0]) {
            /* 把 \0 替换为空格 */
            for (size_t i = 0; cmdline[i]; ++i)
                if (cmdline[i] == 0) cmdline[i] = ' ';
            strncpy(comm, cmdline, sizeof(comm) - 1);
            comm[sizeof(comm) - 1] = 0;
        }
        free(cmdline);

        if (pattern && !strstr(comm, pattern))
            continue;

        printf("%-8ld %-8ld %-8ld %-8c %s\n",
               pid, ppid, rss, state, comm);
    }
    closedir(d);
    return 0;
}

static int sub_top(int argc, char **argv)
{
    int n = 10;
    const char *field = "cpu";
    if (argc >= 3) n = atoi(argv[2]);
    if (argc >= 4) field = argv[3];
    if (n <= 0) n = 10;
    if (strcmp(field, "mem") != 0 && strcmp(field, "cpu") != 0) {
        LOGW("field 必须是 cpu 或 mem,默认 cpu");
        field = "cpu";
    }
    char topn[16];
    snprintf(topn, sizeof(topn), "%d", n);
    /* ps 不直接支持 -n,这里用 head 配合 */
    char script[128];
    if (strcmp(field, "mem") == 0)
        snprintf(script, sizeof(script),
                 "ps -eo pid,ppid,%%cpu,%%mem,rss,comm --sort=-rss | head -n %s",
                 topn);
    else
        snprintf(script, sizeof(script),
                 "ps -eo pid,ppid,%%cpu,%%mem,rss,comm --sort=-pcpu | head -n %s",
                 topn);
    const char *cmd[] = { "sh", "-c", script, NULL };
    return emb_run(cmd, 1);
}

static int sub_log(int argc, char **argv)
{
    int n = 50;
    if (argc >= 3) n = atoi(argv[2]);
    char nbuf[16];
    snprintf(nbuf, sizeof(nbuf), "%d", n);
    /* 优先用 journalctl,回退到 dmesg */
    if (emb_which("journalctl", NULL, 0) == 0) {
        const char *cmd[] = {
            "journalctl", "--no-pager", "-n", nbuf, NULL
        };
        return emb_run(cmd, 1);
    }
    char script[128];
    snprintf(script, sizeof(script),
             "dmesg --color=always 2>/dev/null | tail -n %d", n);
    const char *cmd2[] = { "sh", "-c", script, NULL };
    return emb_run(cmd2, 1);
}

static int sub_perf_record(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools sys perf record <command...>");
        return 1;
    }
    /* perf record -g -- <cmd> */
    const char **cmd = calloc(argc + 3, sizeof(char *));
    if (!cmd) return 1;
    cmd[0] = "perf"; cmd[1] = "record"; cmd[2] = "-g"; cmd[3] = "--";
    for (int i = 2; i < argc; ++i)
        cmd[3 + (i - 1)] = argv[i];
    int rc = emb_run(cmd, 1);
    free(cmd);
    return rc;
}

static int sub_perf_report(int argc, char **argv)
{
    const char *file = (argc >= 3) ? argv[2] : "perf.data";
    const char *cmd[] = { "perf", "report", "-i", file, NULL };
    return emb_run(cmd, 1);
}

static int sub_trace(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools sys trace <event|subsys>  "
             "(如 sched:sched_switch, irq, *, etc.)");
        return 1;
    }
    /* 使用 trace-cmd 子集,如果不存在则用 /sys/kernel/tracing */
    if (emb_which("trace-cmd", NULL, 0) == 0) {
        const char *cmd[] = {
            "trace-cmd", "record", "-e", argv[2], NULL
        };
        return emb_run(cmd, 1);
    }
    /* 直接操作 tracefs */
    LOGI("通过 tracefs 跟踪事件 %s(事件需在 events/ 下)", argv[2]);
    const char *cmd[] = {
        "sh", "-c",
        "TF=/sys/kernel/tracing; "
        "[ -d $TF ] || TF=/sys/kernel/debug/tracing; "
        "echo 0 > $TF/tracing_on; echo > $TF/trace; "
        "echo 1 > $TF/events/$1/enable 2>/dev/null || "
        "echo $1 > $TF/set_event 2>/dev/null; "
        "echo 1 > $TF/tracing_on; "
        "echo === tracing ON (5s) ===; sleep 5; "
        "echo 0 > $TF/tracing_on; cat $TF/trace",
        "sh", argv[2], NULL
    };
    return emb_run(cmd, 1);
}

static int sub_uptime(int argc, char **argv)
{
    (void)argc; (void)argv;
    struct sysinfo si;
    if (sysinfo(&si) != 0) {
        LOGE("sysinfo: %s", strerror(errno));
        return 1;
    }
    long d = si.uptime / 86400;
    long h = (si.uptime % 86400) / 3600;
    long m = (si.uptime % 3600) / 60;
    long s = si.uptime % 60;
    double sc = 1.0 / (1 << SI_LOAD_SHIFT);
    printf("uptime: %ldd %02ldh %02ldm %02lds\n", d, h, m, s);
    printf("load:   %.2f %.2f %.2f\n",
           si.loads[0] * sc, si.loads[1] * sc, si.loads[2] * sc);
    return 0;
}

static int sub_temp(int argc, char **argv)
{
    (void)argc; (void)argv;
    DIR *d = opendir("/sys/class/hwmon");
    if (!d) {
        LOGW("/sys/class/hwmon 不存在");
        return 1;
    }
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] == '.')
            continue;
        char path[256];
        snprintf(path, sizeof(path), "/sys/class/hwmon/%s/name", e->d_name);
        char name[64] = "?";
        emb_read_str(path, name, sizeof(name));
        /* temp*_input */
        char dirp[256];
        snprintf(dirp, sizeof(dirp), "/sys/class/hwmon/%s", e->d_name);
        DIR *sd = opendir(dirp);
        if (!sd) continue;
        struct dirent *se;
        while ((se = readdir(sd)) != NULL) {
            if (strncmp(se->d_name, "temp", 4) != 0)
                continue;
            if (strstr(se->d_name, "_input") == NULL)
                continue;
            char fp[256];
            snprintf(fp, sizeof(fp), "%s/%s", dirp, se->d_name);
            long millic = emb_read_int(fp);
            if (millic >= 0) {
                printf("%s/%s : %.1f C\n", name, se->d_name,
                       millic / 1000.0);
            }
        }
        closedir(sd);
    }
    closedir(d);
    return 0;
}

int cmd_sys(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stdout, "%s", emb_subcmds[2].help);
        return 1;
    }
    const char *sub = argv[1];
    if (strcmp(sub, "cpu") == 0)    return sub_cpu(argc, argv);
    if (strcmp(sub, "mem") == 0)    return sub_mem(argc, argv);
    if (strcmp(sub, "disk") == 0)   return sub_disk(argc, argv);
    if (strcmp(sub, "net") == 0)    return sub_net(argc, argv);
    if (strcmp(sub, "ps") == 0)     return sub_ps(argc, argv);
    if (strcmp(sub, "top") == 0)    return sub_top(argc, argv);
    if (strcmp(sub, "log") == 0)    return sub_log(argc, argv);
    if (strcmp(sub, "uptime") == 0) return sub_uptime(argc, argv);
    if (strcmp(sub, "temp") == 0)   return sub_temp(argc, argv);
    if (strcmp(sub, "perf") == 0) {
        if (argc < 3) {
            LOGE("usage: embtools sys perf <record|report> ...");
            return 1;
        }
        if (strcmp(argv[2], "record") == 0) return sub_perf_record(argc, argv);
        if (strcmp(argv[2], "report") == 0) return sub_perf_report(argc, argv);
        LOGE("未知 perf 子命令: %s", argv[2]);
        return 1;
    }
    if (strcmp(sub, "trace") == 0)  return sub_trace(argc, argv);

    LOGE("未知 sys 子命令: %s", sub);
    fprintf(stdout, "%s", emb_subcmds[2].help);
    return 1;
}
