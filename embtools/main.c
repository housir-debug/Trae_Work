/*
 * main.c - embtools 主入口与子命令分发
 *
 * 用法: embtools <command> [options]
 *
 * 命令:
 *   build   交叉编译与构建管理
 *   hw      设备树与硬件调试
 *   sys     系统监控与性能分析
 *   fs      文件系统与部署
 *   help    显示帮助
 *   -v      显示版本
 */
#include "embtools.h"

#include <string.h>
#include <stdlib.h>

/* 全局子命令表 */
const emb_subcmd_t emb_subcmds[] = {
    { "build", "交叉编译与构建管理",
      "  embtools build <subcommand> [options]\n"
      "    toolchain-info CROSS   显示交叉工具链信息\n"
      "    kernel-config DIR      进入 make menuconfig\n"
      "    kernel-build DIR TGT   编译内核目标(如 zImage/dtbs/modules)\n"
      "    module-build DIR       编译外部模块 (M=DIR)\n"
      "    yocto-layers DIR       列出 bitbake layers\n"
      "    yocto-recipe DIR REC  显示 bitbake recipe 信息\n",
      cmd_build },

    { "hw", "设备树与硬件调试",
      "  embtools hw <subcommand> [options]\n"
      "    dtc-compile SRC.dtb   反编译设备树二进制为 dts\n"
      "    dtc-decompile DTS     编译 dts 为 dtb\n"
      "    gpio list             列出所有已导出 GPIO\n"
      "    gpio get N [N2..]     读取 GPIO 值\n"
      "    gpio set N v          设置 GPIO 输出值\n"
      "    gpio export N         导出 GPIO\n"
      "    gpio unexport N       取消导出 GPIO\n"
      "    i2c detect BUS         扫描 i2c 总线 (i2cdetect)\n"
      "    i2c dump BUS ADDR     读取 i2c 寄存器\n"
      "    i2c set BUS ADDR VAL  写入 i2c 寄存器\n"
      "    spi dev DEV           显示 spi 设备信息\n"
      "    uart DEV [baud]       打开串口终端\n"
      "    reg read ADDR [LEN]   读取 devmem 寄存器\n"
      "    reg write ADDR VAL    写入 devmem 寄存器\n",
      cmd_hw },

    { "sys", "系统监控与性能分析",
      "  embtools sys <subcommand> [options]\n"
      "    cpu                    显示 CPU 使用率与负载\n"
      "    mem                    显示内存与 swap 使用\n"
      "    disk                   显示磁盘 IO\n"
      "    ps [pattern]           列出进程(可选过滤)\n"
      "    top N                  显示 top N 进程(CPU/内存)\n"
      "    log [tail N]           查看 dmesg / journalctl\n"
      "    perf record CMD        perf 录制\n"
      "    perf report [FILE]     perf 报告\n"
      "    trace EVENT            ftrace 跟踪事件\n",
      cmd_sys },

    { "fs", "文件系统与部署",
      "  embtools fs <subcommand> [options]\n"
      "    ls DEV                 列出块设备与分区\n"
      "    mount DEV DIR          挂载设备到目录\n"
      "    umount DIR             卸载\n"
      "    mkrootfs SRC DEV       生成 rootfs 镜像(写入设备)\n"
      "    dd-iso SRC DEV         烧写镜像到设备\n"
      "    nfs-export DIR         输出 NFS 配置片段\n"
      "    tftp-serve DIR         启动 TFTP 服务器(简版)\n"
      "    ota-check DIR          扫描 rootfs 结构\n"
      "    ota-apply SRC DST       应用 OTA 包(单次)\n",
      cmd_fs },

    { NULL, NULL, NULL, NULL }
};

static void show_version(void)
{
    printf(COL_BOLD "embtools" COL_RESET " v%s "
           "(embedded linux engineer assistant)\n",
           EMBTOOLS_VERSION);
}

static void strip_global_opts(int *argc, char ***argv)
{
    int in = 0, out = 0;
    char **a = *argv;
    int n = *argc;
    for (in = 0; in < n; ++in) {
        if (strcmp(a[in], "--no-color") == 0) {
            /* 已在 main 处理 */
            continue;
        }
        if (strcmp(a[in], "-d") == 0 ||
            strcmp(a[in], "--debug") == 0) {
            emb_debug = 1;
            continue;
        }
        a[out++] = a[in];
    }
    *argc = out;
}

int main(int argc, char **argv)
{
    emb_color_autoinit();

    /* 提前处理 --no-color / -d / --debug */
    int filtered = 0;
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--no-color") == 0) {
            filtered = 1;
        }
    }
    (void)filtered;
    strip_global_opts(&argc, &argv);

    if (argc < 2) {
        emb_usage();
        return 1;
    }

    const char *cmd = argv[1];

    if (strcmp(cmd, "-v") == 0 || strcmp(cmd, "--version") == 0) {
        show_version();
        return 0;
    }
    if (strcmp(cmd, "help") == 0 || strcmp(cmd, "-h") == 0 ||
        strcmp(cmd, "--help") == 0) {
        if (argc >= 3) {
            /* embtools help build => 显示 build 子命令帮助 */
            for (const emb_subcmd_t *p = emb_subcmds; p->name; ++p) {
                if (strcmp(p->name, argv[2]) == 0) {
                    fprintf(stdout, COL_BOLD "%s" COL_RESET "\n%s\n",
                            p->name, p->help);
                    return 0;
                }
            }
            LOGE("未知子命令: %s", argv[2]);
            return 1;
        }
        emb_usage();
        return 0;
    }

    /* 查表分发 */
    for (const emb_subcmd_t *p = emb_subcmds; p->name; ++p) {
        if (strcmp(p->name, cmd) == 0) {
            /* 把 argv[1] 替换成 argv[0] 路径,让子命令解析 argv[1..] */
            argv[1] = argv[0];
            return p->handler(argc - 1, argv + 1);
        }
    }

    LOGE("未知命令: %s(运行 embtools help 查看可用命令)", cmd);
    return 1;
}
