/*
 * cmd_build.c - 交叉编译与构建管理
 *
 * 子命令:
 *   toolchain-info CROSS              - 显示交叉工具链信息
 *   kernel-config   DIR               - make menuconfig
 *   kernel-build    DIR TARGET        - 编译内核目标
 *   module-build    DIR               - 编译外部模块
 *   yocto-layers    DIR               - 列出 bitbake layers
 *   yocto-recipe    DIR RECIPE        - bitbake -c listtasks/show
 *   buildroot-info  DIR               - 列出 buildroot defconfig
 */
#include "embtools.h"

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* 在子目录下查找内核源码特征文件,辅助确认是否是内核源码 */
static int looks_like_kernel(const char *dir)
{
    char path[4096];
    const char *markers[] = { "Makefile", "Kconfig", "init/Kconfig" };
    for (size_t i = 0; i < sizeof(markers) / sizeof(markers[0]); ++i) {
        snprintf(path, sizeof(path), "%s/%s", dir, markers[i]);
        if (access(path, F_OK) == 0)
            return 1;
    }
    return 0;
}

static int has_file(const char *dir, const char *name)
{
    char path[4096];
    snprintf(path, sizeof(path), "%s/%s", dir, name);
    return access(path, F_OK) == 0;
}

/* ------- toolchain-info: 用交叉工具链打印版本/架构信息 ------- */
static int sub_toolchain_info(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("用法: embtools build toolchain-info <prefix>"
             "(例如 arm-linux-gnueabihf-)");
        return 1;
    }
    const char *prefix = argv[2];

    char cmd[256];
    char path[PATH_MAX];
    snprintf(cmd, sizeof(cmd), "%sgcc", prefix);
    if (emb_which(cmd, path, sizeof(path)) < 0) {
        LOGE("找不到工具链 %s(请检查 PATH)", cmd);
        return 1;
    }

    printf(COL_BOLD "工具链前缀" COL_RESET ": %s\n", prefix);
    printf(COL_BOLD "gcc 路径" COL_RESET "   : %s\n", path);

    /* 调用 gcc -v 获取版本 */
    const char *cmd_v[] = { cmd, "-v", NULL };
    printf("\n" COL_BOLD "[gcc 版本]" COL_RESET "\n");
    int rc = emb_run(cmd_v, 1);
    if (rc != 0) {
        LOGW("gcc -v 退出码 %d", rc);
    }

    /* 打印目标三元组 */
    const char *cmd_dump[] = { cmd, "-dumpmachine", NULL };
    printf("\n" COL_BOLD "[目标三元组]" COL_RESET "\n  ");
    fflush(stdout);
    emb_run(cmd_dump, 0);
    printf("\n");

    /* 列出工具链中的其它工具 */
    printf("\n" COL_BOLD "[工具链组件]" COL_RESET "\n");
    const char *tools[] = { "g++", "ld", "as", "ar", "nm", "objcopy",
                            "objdump", "strip", "readelf", "size" };
    for (size_t i = 0; i < sizeof(tools) / sizeof(tools[0]); ++i) {
        snprintf(cmd, sizeof(cmd), "%s%s", prefix, tools[i]);
        if (emb_which(cmd, path, sizeof(path)) == 0) {
            printf("  " COL_GREEN "%-10s" COL_RESET " %s\n", tools[i], path);
        }
    }
    return 0;
}

/* ------- kernel-config: 进入 menuconfig ------- */
static int sub_kernel_config(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("用法: embtools build kernel-config <kernel-src-dir>");
        return 1;
    }
    const char *dir = argv[2];
    if (!looks_like_kernel(dir)) {
        LOGE("%s 不像内核源码目录(Missing Makefile/Kconfig)", dir);
        return 1;
    }
    if (chdir(dir) != 0) {
        LOGE("chdir %s: %s", dir, strerror(errno));
        return 1;
    }
    LOGI("进入 make menuconfig (Ctrl+C 退出)");
    const char *cmd[] = { "make", "menuconfig", NULL };
    return emb_run(cmd, 1);
}

/* ------- kernel-build: 编译内核目标 ------- */
static int sub_kernel_build(int argc, char **argv)
{
    if (argc < 4) {
        LOGE("用法: embtools build kernel-build <dir> <target>"
             "(target 例: zImage, dtbs, modules, modules_install)");
        return 1;
    }
    const char *dir = argv[2];
    const char *target = argv[3];

    if (!looks_like_kernel(dir)) {
        LOGE("%s 不像内核源码目录", dir);
        return 1;
    }
    if (chdir(dir) != 0) {
        LOGE("chdir %s: %s", dir, strerror(errno));
        return 1;
    }

    /* 检查是否有 .config,没有则提示 */
    if (access(".config", F_OK) != 0) {
        LOGW("未发现 .config,正在尝试 defconfig 提示...");
        printf("  你可能需要先运行:\n"
               "    make ARCH=arm defconfig\n"
               "    make menuconfig\n");
        return 1;
    }

    /* 计算并行度 */
    long ncpu = sysconf(_SC_NPROCESSORS_ONLN);
    if (ncpu < 1) ncpu = 1;
    char jflag[32];
    snprintf(jflag, sizeof(jflag), "-j%ld", ncpu);

    LOGI("编译 %s (%s)", target, jflag);
    const char *cmd[] = { "make", jflag, target, NULL };
    return emb_run(cmd, 1);
}

/* ------- module-build: 编译外部模块 (M=DIR) ------- */
static int sub_module_build(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("用法: embtools build module-build <module-dir>"
             " [--kernel DIR]");
        return 1;
    }
    const char *mdir = argv[2];
    const char *kdir = NULL;
    char *kdir_owned = NULL;  /* 自有副本,函数末尾需 free */

    for (int i = 3; i < argc; ++i) {
        if (strcmp(argv[i], "--kernel") == 0 && i + 1 < argc) {
            kdir = argv[++i];
        }
    }

    if (!kdir) {
        /* 尝试从 /lib/modules/$(uname -r)/build 推断 */
        char ubuild[4096];
        FILE *p = popen("uname -r", "r");
        char rev[64] = "";
        if (p) {
            if (fgets(rev, sizeof(rev), p)) {
                rev[strcspn(rev, "\n")] = 0;
            }
            pclose(p);
        }
        snprintf(ubuild, sizeof(ubuild), "/lib/modules/%s/build", rev);
        if (access(ubuild, F_OK) == 0) {
            /* 复制一份,避免 dangling 指针告警;随 cmd 数组一起使用 */
            kdir_owned = strdup(ubuild);
            kdir = kdir_owned;
        }
    }
    if (!kdir) {
        LOGE("未指定 --kernel DIR,且无法从 /lib/modules 自动定位内核源码");
        return 1;
    }

    char mparam[4096];
    snprintf(mparam, sizeof(mparam), "M=%s", mdir);

    long ncpu = sysconf(_SC_NPROCESSORS_ONLN);
    if (ncpu < 1) ncpu = 1;
    char jflag[32];
    snprintf(jflag, sizeof(jflag), "-j%ld", ncpu);

    LOGI("编译外部模块 %s (内核 %s, %s)", mdir, kdir, jflag);
    const char *cmd[] = {
        "make", "-C", kdir, jflag, mparam, "modules", NULL
    };
    int rc = emb_run(cmd, 1);
    free(kdir_owned);
    return rc;
}

/* ------- yocto-layers: 列出 bitbake layers ------- */
static int sub_yocto_layers(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("用法: embtools build yocto-layers <yocto-build-dir>");
        return 1;
    }
    const char *dir = argv[2];

    if (!has_file(dir, "poky") && !has_file(dir, "build") &&
        !has_file(dir, "bitbake")) {
        LOGW("%s 可能不是 Yocto 目录", dir);
    }
    if (chdir(dir) != 0) {
        LOGE("chdir %s: %s", dir, strerror(errno));
        return 1;
    }
    /* 优先用 source oe-init-build-env,再 bitbake-layers show-layers */
    LOGI("运行 bitbake-layers show-layers (需要 source 环境)");
    const char *cmd[] = {
        "sh", "-c",
        "source oe-init-build-env > /dev/null 2>&1 && bitbake-layers show-layers",
        NULL
    };
    return emb_run(cmd, 1);
}

/* ------- yocto-recipe: 显示 bitbake recipe 信息 ------- */
static int sub_yocto_recipe(int argc, char **argv)
{
    if (argc < 4) {
        LOGE("用法: embtools build yocto-recipe <dir> <recipe>"
             "(例如 embtools build yocto-recipe ./poky linux-raspberrypi)");
        return 1;
    }
    const char *dir = argv[2];
    const char *recipe = argv[3];
    if (chdir(dir) != 0) {
        LOGE("chdir %s: %s", dir, strerror(errno));
        return 1;
    }
    char script[4096];
    snprintf(script, sizeof(script),
             "source oe-init-build-env > /dev/null 2>&1 && "
             "echo === recipe info === && bitbake -e %s | "
             "grep -E '^(PN|PV|PR|SECTION|DESCRIPTION|LICENSE|SRC_URI|SRCREV|S|B|WORKDIR|D)=' "
             " | head -n 30",
             recipe);
    const char *cmd[] = { "sh", "-c", script, NULL };
    return emb_run(cmd, 1);
}

/* ------- buildroot-info: 列出 defconfig ------- */
static int sub_buildroot_info(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools build buildroot-info <buildroot-dir>");
        return 1;
    }
    const char *dir = argv[2];
    char cfgdir[4096];
    snprintf(cfgdir, sizeof(cfgdir), "%s/configs", dir);
    if (access(cfgdir, F_OK) != 0) {
        LOGE("%s 不是 buildroot 目录(缺 configs/)", dir);
        return 1;
    }
    printf(COL_BOLD "可用 defconfig:" COL_RESET "\n");
    char cmd[4096];
    snprintf(cmd, sizeof(cmd), "ls %s/configs | column -c 80", dir);
    const char *argv2[] = { "sh", "-c", cmd, NULL };
    return emb_run(argv2, 1);
}

/* ------- build 命令分派 ------- */
int cmd_build(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stdout, "%s", emb_subcmds[0].help);
        return 1;
    }
    const char *sub = argv[1];
    if (strcmp(sub, "toolchain-info") == 0) return sub_toolchain_info(argc, argv);
    if (strcmp(sub, "kernel-config")   == 0) return sub_kernel_config(argc, argv);
    if (strcmp(sub, "kernel-build")    == 0) return sub_kernel_build(argc, argv);
    if (strcmp(sub, "module-build")    == 0) return sub_module_build(argc, argv);
    if (strcmp(sub, "yocto-layers")    == 0) return sub_yocto_layers(argc, argv);
    if (strcmp(sub, "yocto-recipe")    == 0) return sub_yocto_recipe(argc, argv);
    if (strcmp(sub, "buildroot-info")  == 0) return sub_buildroot_info(argc, argv);

    LOGE("未知 build 子命令: %s", sub);
    fprintf(stdout, "%s", emb_subcmds[0].help);
    return 1;
}
