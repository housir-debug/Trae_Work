/*
 * cmd_hw.c - 设备树与硬件调试
 *
 * 子命令:
 *   dtc-decompile SRC.dtb        - 反编译 dtb 为 dts
 *   dtc-compile  SRC.dts [DTS]   - 编译 dts 为 dtb
 *   gpio list                    - 列出已导出的 GPIO
 *   gpio get N [N2..]            - 读取 GPIO 值
 *   gpio set N v                 - 设置 GPIO 输出
 *   gpio export N [direction]    - 导出 GPIO
 *   gpio unexport N               - 取消导出
 *   i2c detect BUS               - 扫描 i2c 总线
 *   i2c dump BUS ADDR [LEN]      - 读取 i2c 寄存器
 *   i2c set BUS ADDR VAL         - 写入 i2c 寄存器
 *   spi dev DEV                  - 显示 spi 设备信息
 *   uart DEV [baud]              - 打开串口终端
 *   reg read ADDR [LEN]          - 读取 devmem 寄存器
 *   reg write ADDR VAL [WIDTH]   - 写入 devmem 寄存器
 */
#include "embtools.h"

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

/* ============================ 设备树 ============================ */

static int run_dtc(const char *infile, const char *outfile,
                   const char *fmt_in, const char *fmt_out)
{
    if (emb_which("dtc", NULL, 0) < 0) {
        LOGE("找不到 dtc (device tree compiler),请安装");
        return 1;
    }
    const char *cmd[] = {
        "dtc", "-O", fmt_out, "-I", fmt_in,
        "-o", outfile, infile, NULL
    };
    return emb_run(cmd, 1);
}

static int sub_dtc_decompile(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools hw dtc-decompile <file.dtb>");
        return 1;
    }
    const char *src = argv[2];
    char out[4096];
    snprintf(out, sizeof(out), "%s.dts", src);
    LOGI("反编译 %s -> %s", src, out);
    return run_dtc(src, out, "dtb", "dts");
}

static int sub_dtc_compile(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools hw dtc-compile <file.dts> [output.dtb]");
        return 1;
    }
    const char *src = argv[2];
    char out[4096];
    if (argc >= 4)
        snprintf(out, sizeof(out), "%s", argv[3]);
    else
        snprintf(out, sizeof(out), "%s.dtb", src);
    LOGI("编译 %s -> %s", src, out);
    return run_dtc(src, out, "dts", "dtb");
}

/* ============================ GPIO ============================ */

#define SYS_GPIO_CLASS "/sys/class/gpio"

/* 把数字 GPIO 写入 export/unexport 文件 */
static int gpio_export_one(int n, int export)
{
    char path[256];
    char val[16];
    snprintf(path, sizeof(path), "%s/%s",
             SYS_GPIO_CLASS, export ? "export" : "unexport");
    snprintf(val, sizeof(val), "%d", n);
    int fd = open(path, O_WRONLY);
    if (fd < 0) {
        LOGE("open %s: %s", path, strerror(errno));
        return -1;
    }
    ssize_t w = write(fd, val, strlen(val));
    close(fd);
    if (w < 0) {
        /* GPIO 可能已经导出 */
        if (errno != EBUSY && errno != EINVAL)
            LOGW("gpio %d %s: %s", n, export ? "export" : "unexport",
                 strerror(errno));
        return -1;
    }
    return 0;
}

static int gpio_dir_path(int n, const char *sub, char *out, size_t outsz)
{
    return snprintf(out, outsz, "%s/gpio%d/%s",
                    SYS_GPIO_CLASS, n, sub);
}

static int gpio_write_file(int n, const char *sub, const char *val)
{
    char path[256];
    gpio_dir_path(n, sub, path, sizeof(path));
    int fd = open(path, O_WRONLY);
    if (fd < 0) {
        LOGE("open %s: %s", path, strerror(errno));
        return -1;
    }
    ssize_t w = write(fd, val, strlen(val));
    close(fd);
    if (w < 0) {
        LOGE("write %s=%s: %s", path, val, strerror(errno));
        return -1;
    }
    return 0;
}

static int gpio_read_one(int n)
{
    char path[256];
    char buf[16];
    gpio_dir_path(n, "value", path, sizeof(path));
    if (emb_read_str(path, buf, sizeof(buf)) < 0) {
        LOGE("读 %s 失败(GPIO 未导出?)", path);
        return -1;
    }
    printf("gpio%-3d = %s\n", n, buf);
    return 0;
}

static int sub_gpio_list(int argc, char **argv)
{
    (void)argc; (void)argv;
    DIR *d = opendir(SYS_GPIO_CLASS);
    if (!d) {
        LOGE("open %s: %s (内核可能使用 pinctrl 替代)", SYS_GPIO_CLASS,
             strerror(errno));
        return 1;
    }
    printf(COL_BOLD "%-10s %-10s %-8s %s\n" COL_RESET,
           "GPIO", "DIR", "VALUE", "EDGE");
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (strncmp(e->d_name, "gpio", 4) != 0)
            continue;
        char *end;
        long n = strtol(e->d_name + 4, &end, 10);
        if (*end != 0)
            continue;
        char path[256];
        char buf[32];
        const char *dir_s = "?", *val_s = "?", *edge_s = "?";
        gpio_dir_path((int)n, "direction", path, sizeof(path));
        if (emb_read_str(path, buf, sizeof(buf)) == 0) dir_s = buf;
        gpio_dir_path((int)n, "value", path, sizeof(path));
        if (emb_read_str(path, buf, sizeof(buf)) == 0) val_s = buf;
        gpio_dir_path((int)n, "edge", path, sizeof(path));
        if (emb_read_str(path, buf, sizeof(buf)) == 0) edge_s = buf;
        printf("%-10ld %-10s %-8s %s\n", n, dir_s, val_s, edge_s);
    }
    closedir(d);
    return 0;
}

static int sub_gpio_get(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools hw gpio get N [N2 ... | all | a..b]");
        return 1;
    }
    /* 支持多个参数 */
    for (int i = 2; i < argc; ++i) {
        if (strcmp(argv[i], "all") == 0 ||
            strchr(argv[i], '.') || strchr(argv[i], ',')) {
            int list[1024], cnt = 0;
            if (emb_parse_range(argv[i], 0, 10000, list,
                                sizeof(list)/sizeof(list[0]), &cnt) < 0) {
                LOGE("无法解析范围 %s", argv[i]);
                return 1;
            }
            for (int k = 0; k < cnt; ++k)
                gpio_read_one(list[k]);
        } else {
            int n = atoi(argv[i]);
            gpio_read_one(n);
        }
    }
    return 0;
}

static int sub_gpio_set(int argc, char **argv)
{
    if (argc < 4) {
        LOGE("usage: embtools hw gpio set N value(0/1)");
        return 1;
    }
    int n = atoi(argv[2]);
    const char *val = argv[3];
    if (strcmp(val, "1") != 0 && strcmp(val, "0") != 0) {
        LOGE("值必须是 0 或 1");
        return 1;
    }
    /* 自动设为输出方向 */
    char path[256], tmp[16];
    gpio_dir_path(n, "direction", path, sizeof(path));
    if (emb_read_str(path, tmp, sizeof(tmp)) == 0 &&
        strcmp(tmp, "out") != 0) {
        gpio_write_file(n, "direction", "out");
    }
    return gpio_write_file(n, "value", val) == 0 ? 0 : 1;
}

static int sub_gpio_export(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools hw gpio export N [in|out]");
        return 1;
    }
    int n = atoi(argv[2]);
    const char *dir = (argc >= 4) ? argv[3] : "in";
    if (strcmp(dir, "in") != 0 && strcmp(dir, "out") != 0) {
        LOGE("方向必须是 in 或 out");
        return 1;
    }
    gpio_export_one(n, 1);
    /* 等待 sysfs 节点创建 */
    usleep(50 * 1000);
    gpio_write_file(n, "direction", dir);
    LOGI("gpio%d 已导出,方向 %s", n, dir);
    return 0;
}

static int sub_gpio_unexport(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools hw gpio unexport N");
        return 1;
    }
    int n = atoi(argv[2]);
    gpio_export_one(n, 0);
    LOGI("gpio%d 已取消导出", n);
    return 0;
}

/* ============================ I2C ============================ */

static int sub_i2c_detect(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools hw i2c detect <bus-num>");
        return 1;
    }
    const char *bus = argv[2];
    const char *cmd[] = { "i2cdetect", "-y", bus, NULL };
    return emb_run(cmd, 1);
}

static int sub_i2c_dump(int argc, char **argv)
{
    if (argc < 4) {
        LOGE("usage: embtools hw i2c dump <bus> <addr>");
        return 1;
    }
    const char *bus = argv[2];
    const char *addr = argv[3];
    const char *cmd[] = { "i2cdump", "-y", "-f", bus, addr, NULL };
    return emb_run(cmd, 1);
}

static int sub_i2c_set(int argc, char **argv)
{
    if (argc < 5) {
        LOGE("usage: embtools hw i2c set <bus> <addr> <val>");
        return 1;
    }
    const char *bus = argv[2];
    const char *addr = argv[3];
    const char *val = argv[4];
    const char *cmd[] = {
        "i2cset", "-y", bus, addr, val, NULL
    };
    return emb_run(cmd, 1);
}

/* ============================ SPI ============================ */

static int sub_spi_dev(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools hw spi dev <spi-device>");
        return 1;
    }
    const char *dev = argv[2];
    /* 列出 spidev 信息:设备名、节点、绑定 driver */
    char syspath[4096];
    snprintf(syspath, sizeof(syspath), "/sys/class/spidev/%s/device", dev);
    char driverlink[4096];
    snprintf(driverlink, sizeof(driverlink), "%s/driver", syspath);
    char drvname[256] = "(none)";
    char realp[4096];
    ssize_t rl = readlink(driverlink, realp, sizeof(realp)-1);
    if (rl > 0) {
        realp[rl] = 0;
        const char *base = strrchr(realp, '/');
        snprintf(drvname, sizeof(drvname), "%s", base ? base + 1 : realp);
    }
    printf("dev      : %s\n", dev);
    printf("driver   : %s\n", drvname);
    /* /dev/spidevX.Y */
    char devpath[256];
    snprintf(devpath, sizeof(devpath), "/dev/%s", dev);
    printf("path     : %s\n", devpath);
    if (access(devpath, F_OK) != 0) {
        LOGW("设备节点 %s 不存在", devpath);
    }
    return 0;
}

/* ============================ UART ============================ */

/* 设置串口为原始模式 + 指定波特率 */
static int uart_setup(int fd, speed_t baud)
{
    struct termios t;
    if (tcgetattr(fd, &t) != 0) {
        LOGE("tcgetattr: %s", strerror(errno));
        return -1;
    }
    cfmakeraw(&t);
    cfsetispeed(&t, baud);
    cfsetospeed(&t, baud);
    t.c_cflag |= CLOCAL | CREAD;
    if (tcsetattr(fd, TCSANOW, &t) != 0) {
        LOGE("tcsetattr: %s", strerror(errno));
        return -1;
    }
    return 0;
}

static speed_t baud_to_speed(const char *s)
{
    int b = atoi(s);
    switch (b) {
        case 9600:   return B9600;
        case 19200:  return B19200;
        case 38400:  return B38400;
        case 57600:  return B57600;
        case 115200: return B115200;
        case 230400: return B230400;
        case 460800: return B460800;
        case 921600: return B921600;
        default:
            LOGW("不支持 %d,使用 115200", b);
            return B115200;
    }
}

static int sub_uart(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools hw uart <dev> [baud]");
        return 1;
    }
    const char *dev = argv[2];
    speed_t baud = (argc >= 4) ? baud_to_speed(argv[3]) : B115200;

    int fd = open(dev, O_RDWR | O_NOCTTY);
    if (fd < 0) {
        LOGE("open %s: %s", dev, strerror(errno));
        return 1;
    }
    if (uart_setup(fd, baud) < 0) {
        close(fd);
        return 1;
    }
    LOGI("已打开 %s @ %s,按 Ctrl+] 退出,输入即发送", dev,
         argc >= 4 ? argv[3] : "115200");

    /* 简单的双向桥接:fork 子进程读串口,父进程读 stdin */
    pid_t pid = fork();
    if (pid < 0) {
        LOGE("fork: %s", strerror(errno));
        close(fd);
        return 1;
    }
    if (pid == 0) {
        /* 子进程:串口 -> stdout */
        char buf[4096];
        ssize_t n;
        while ((n = read(fd, buf, sizeof(buf))) > 0) {
            ssize_t w = write(STDOUT_FILENO, buf, n);
            (void)w;
        }
        _exit(0);
    }
    /* 父进程:stdin -> 串口 */
    char buf[4096];
    ssize_t n;
    int stop = 0;
    while (!stop && (n = read(STDIN_FILENO, buf, sizeof(buf))) > 0) {
        if (buf[0] == 0x1d) {  /* Ctrl+] */
            stop = 1;
            break;
        }
        ssize_t w = write(fd, buf, n);
        (void)w;
    }
    kill(pid, SIGTERM);
    waitpid(pid, NULL, 0);
    close(fd);
    return 0;
}

/* ============================ 寄存器 devmem ============================ */

static int sub_reg_read(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools hw reg read <addr> [count]");
        return 1;
    }
    const char *addr = argv[2];
    const char *cnt  = (argc >= 4) ? argv[3] : "1";
    const char *cmd[] = {
        "devmem", addr, "32", NULL
    };
    if (strcmp(cnt, "1") == 0) {
        return emb_run(cmd, 1);
    }
    /* 多个寄存器:自己 mmap 读取,避免反复调用 devmem */
    unsigned long base = strtoul(addr, NULL, 0);
    int n = atoi(cnt);
    int memfd = open("/dev/mem", O_RDONLY);
    if (memfd < 0) {
        LOGE("open /dev/mem: %s (需要 root)", strerror(errno));
        return 1;
    }
    size_t mapsize = n * 4;
    /* 对齐到页 */
    size_t pgsz = sysconf(_SC_PAGESIZE);
    off_t aligned = base & ~(off_t)(pgsz - 1);
    size_t off = base - aligned;
    volatile void *m = mmap(NULL, off + mapsize, PROT_READ,
                            MAP_SHARED, memfd, aligned);
    if (m == MAP_FAILED) {
        LOGE("mmap: %s", strerror(errno));
        close(memfd);
        return 1;
    }
    const volatile unsigned int *p = (const volatile unsigned int *)((char *)m + off);
    for (int i = 0; i < n; ++i) {
        printf("0x%08lx = 0x%08x\n",
               base + (unsigned long)i * 4, p[i]);
    }
    munmap((void *)m, off + mapsize);
    close(memfd);
    return 0;
}

static int sub_reg_write(int argc, char **argv)
{
    if (argc < 4) {
        LOGE("usage: embtools hw reg write <addr> <val> [8|16|32]");
        return 1;
    }
    const char *addr = argv[2];
    const char *val  = argv[3];
    const char *w    = (argc >= 5) ? argv[4] : "32";
    const char *cmd[] = { "devmem", addr, w, val, NULL };
    return emb_run(cmd, 1);
}

/* ============================ hw 命令分派 ============================ */

int cmd_hw(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stdout, "%s", emb_subcmds[1].help);
        return 1;
    }
    const char *sub = argv[1];

    if (strcmp(sub, "dtc-decompile") == 0) return sub_dtc_decompile(argc, argv);
    if (strcmp(sub, "dtc-compile")   == 0) return sub_dtc_compile(argc, argv);
    if (strcmp(sub, "gpio")          == 0) {
        if (argc < 3) {
            LOGE("usage: embtools hw gpio <list|get|set|export|unexport> ...");
            return 1;
        }
        const char *g = argv[2];
        if (strcmp(g, "list") == 0)    return sub_gpio_list(argc, argv);
        if (strcmp(g, "get") == 0)     return sub_gpio_get(argc, argv);
        if (strcmp(g, "set") == 0)     return sub_gpio_set(argc, argv);
        if (strcmp(g, "export") == 0)  return sub_gpio_export(argc, argv);
        if (strcmp(g, "unexport") == 0)return sub_gpio_unexport(argc, argv);
        LOGE("未知 gpio 子命令: %s", g);
        return 1;
    }
    if (strcmp(sub, "i2c") == 0) {
        if (argc < 3) {
            LOGE("usage: embtools hw i2c <detect|dump|set> ...");
            return 1;
        }
        const char *i = argv[2];
        if (strcmp(i, "detect") == 0) return sub_i2c_detect(argc, argv);
        if (strcmp(i, "dump") == 0)   return sub_i2c_dump(argc, argv);
        if (strcmp(i, "set") == 0)    return sub_i2c_set(argc, argv);
        LOGE("未知 i2c 子命令: %s", i);
        return 1;
    }
    if (strcmp(sub, "spi") == 0) {
        if (argc < 3 || strcmp(argv[2], "dev") != 0) {
            LOGE("usage: embtools hw spi dev <spi-device>");
            return 1;
        }
        return sub_spi_dev(argc, argv);
    }
    if (strcmp(sub, "uart") == 0) return sub_uart(argc, argv);
    if (strcmp(sub, "reg")  == 0) {
        if (argc < 3) {
            LOGE("usage: embtools hw reg <read|write> ...");
            return 1;
        }
        const char *r = argv[2];
        if (strcmp(r, "read") == 0)  return sub_reg_read(argc, argv);
        if (strcmp(r, "write") == 0) return sub_reg_write(argc, argv);
        LOGE("未知 reg 子命令: %s", r);
        return 1;
    }

    LOGE("未知 hw 子命令: %s", sub);
    fprintf(stdout, "%s", emb_subcmds[1].help);
    return 1;
}
