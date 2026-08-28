/*
 * cmd_fs.c - 文件系统与部署
 *
 * 子命令:
 *   ls                       - 列出块设备与分区
 *   mount DEV DIR            - 挂载设备
 *   umount DIR               - 卸载
 *   mkrootfs SRC DEV         - 把目录树打成镜像并写入设备
 *   dd-iso SRC DEV [bs]      - 烧写镜像
 *   nfs-export DIR           - 输出 NFS exports 配置片段
 *   tftp-serve DIR [PORT]    - 启动简版 TFTP 服务器(UDP 69)
 *   ota-check DIR            - 扫描 rootfs 结构,提示必要目录
 *   ota-apply SRC DST        - 应用 OTA 包(tar)到目标目录
 */
#include "embtools.h"

#include <arpa/inet.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/uio.h>
#include <unistd.h>

/* ============================ 块设备列表 ============================ */

/* 从 /sys/block 读 size (512B 单位) */
static unsigned long long block_size_sectors(const char *dev)
{
    char path[256];
    snprintf(path, sizeof(path), "/sys/block/%s/size", dev);
    long v = emb_read_int(path);
    return v < 0 ? 0 : (unsigned long long)v;
}

/* 设备是否可移动 */
static int block_removable(const char *dev)
{
    char path[256];
    snprintf(path, sizeof(path), "/sys/block/%s/removable", dev);
    long v = emb_read_int(path);
    return v == 1;
}

static int block_vendor(const char *dev, char *out, size_t outsz)
{
    char path[256];
    snprintf(path, sizeof(path), "/sys/block/%s/device/vendor", dev);
    return emb_read_str(path, out, outsz);
}

static int block_model(const char *dev, char *out, size_t outsz)
{
    char path[256];
    snprintf(path, sizeof(path), "/sys/block/%s/device/model", dev);
    return emb_read_str(path, out, outsz);
}

static int sub_ls(int argc, char **argv)
{
    (void)argc; (void)argv;
    DIR *d = opendir("/sys/block");
    if (!d) {
        LOGE("open /sys/block: %s", strerror(errno));
        return 1;
    }
    printf(COL_BOLD "%-12s %-12s %-14s %-8s %-16s %s\n" COL_RESET,
           "DEVICE", "SIZE", "SECTORS", "RM", "VENDOR/MODEL", "PARTITIONS");
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (e->d_name[0] == '.')
            continue;
        /* 跳过 loop/ram 等 */
        if (strncmp(e->d_name, "loop", 4) == 0 ||
            strncmp(e->d_name, "ram", 3) == 0 ||
            strncmp(e->d_name, "zram", 4) == 0)
            continue;
        unsigned long long sect = block_size_sectors(e->d_name);
        unsigned long long bytes = sect * 512ULL;
        char sz[16];
        emb_human_size(bytes, sz, sizeof(sz));
        int rm = block_removable(e->d_name);
        char vendor[64] = "", model[64] = "";
        block_vendor(e->d_name, vendor, sizeof(vendor));
        block_model(e->d_name, model, sizeof(model));
        char vm[128];
        snprintf(vm, sizeof(vm), "%s %s", vendor, model);
        /* 子分区 */
        char pdir[256];
        snprintf(pdir, sizeof(pdir), "/sys/block/%s", e->d_name);
        DIR *pd = opendir(pdir);
        char parts[256] = "";
        if (pd) {
            struct dirent *pe;
            int first = 1;
            while ((pe = readdir(pd)) != NULL) {
                if (strncmp(pe->d_name, e->d_name,
                            strlen(e->d_name)) != 0)
                    continue;
                if (!first) strncat(parts, ",", sizeof(parts)-strlen(parts)-1);
                strncat(parts, pe->d_name, sizeof(parts)-strlen(parts)-1);
                first = 0;
            }
            closedir(pd);
        }
        printf("%-12s %-12s %-14llu %-8d %-16s %s\n",
               e->d_name, sz, sect, rm, vm, parts[0] ? parts : "-");
    }
    closedir(d);
    return 0;
}

/* ============================ mount/umount ============================ */

static int sub_mount(int argc, char **argv)
{
    if (argc < 4) {
        LOGE("usage: embtools fs mount <dev> <dir> [fstype]");
        return 1;
    }
    const char *dev = argv[2];
    const char *dir = argv[3];
    const char *fstype = (argc >= 5) ? argv[4] : NULL;
    /* mkdir -p dir */
    if (access(dir, F_OK) != 0) {
        if (mkdir(dir, 0755) != 0 && errno != EEXIST) {
            LOGW("mkdir %s: %s", dir, strerror(errno));
        }
    }
    unsigned long flags = 0;
    if (mount(dev, dir, fstype, flags, NULL) != 0) {
        LOGE("mount %s -> %s: %s", dev, dir, strerror(errno));
        return 1;
    }
    LOGI("已挂载 %s -> %s", dev, dir);
    return 0;
}

static int sub_umount(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools fs umount <dir|dev>");
        return 1;
    }
    if (umount(argv[2]) != 0) {
        LOGE("umount %s: %s", argv[2], strerror(errno));
        return 1;
    }
    LOGI("已卸载 %s", argv[2]);
    return 0;
}

/* ============================ dd-iso 烧写 ============================ */

static int confirm_write(const char *dev)
{
    fprintf(stderr,
            COL_YELLOW "即将写入设备 %s,该设备所有数据将丢失!\n"
            "5 秒内按 Ctrl+C 取消..." COL_RESET "\n", dev);
    for (int i = 5; i > 0; --i) {
        fprintf(stderr, "%d... ", i);
        fflush(stderr);
        sleep(1);
    }
    fprintf(stderr, "GO\n");
    return 0;
}

static int sub_dd_iso(int argc, char **argv)
{
    if (argc < 4) {
        LOGE("usage: embtools fs dd-iso <src.img> <dev> [bs=4M]");
        return 1;
    }
    const char *src = argv[2];
    const char *dev = argv[3];
    const char *bs = (argc >= 5) ? argv[4] : "4M";

    if (access(src, R_OK) != 0) {
        LOGE("源文件 %s 不可读: %s", src, strerror(errno));
        return 1;
    }
    char devpath[256];
    snprintf(devpath, sizeof(devpath), "/dev/%s",
             (strncmp(dev, "/dev/", 5) == 0) ? dev + 5 : dev);
    if (access(devpath, W_OK) != 0) {
        LOGE("目标 %s 不可写 (需要 root): %s", devpath, strerror(errno));
        return 1;
    }
    confirm_write(devpath);

    char script[1024];
    snprintf(script, sizeof(script),
             "dd if=%s of=%s bs=%s status=progress conv=fsync",
             src, devpath, bs);
    const char *cmd[] = { "sh", "-c", script, NULL };
    int rc = emb_run(cmd, 1);
    if (rc == 0) {
        LOGI("烧写完成,正在 sync...");
        sync();
    }
    return rc;
}

/* ============================ mkrootfs ============================ */

/* 把目录树打包为 ext4/squashfs 镜像 */
static int sub_mkrootfs(int argc, char **argv)
{
    if (argc < 4) {
        LOGE("usage: embtools fs mkrootfs <src-dir> <out.img> [ext4|squashfs]");
        return 1;
    }
    const char *src = argv[2];
    const char *out = argv[3];
    const char *fmt = (argc >= 5) ? argv[4] : "ext4";

    if (access(src, F_OK) != 0) {
        LOGE("源目录 %s 不存在", src);
        return 1;
    }

    if (strcmp(fmt, "squashfs") == 0) {
        if (emb_which("mksquashfs", NULL, 0) < 0) {
            LOGE("需要 mksquashfs");
            return 1;
        }
        const char *cmd[] = { "mksquashfs", src, out, "-comp", "xz", "-noappend", NULL };
        return emb_run(cmd, 1);
    }

    if (strcmp(fmt, "ext4") != 0) {
        LOGE("仅支持 ext4 / squashfs");
        return 1;
    }
    if (emb_which("mkfs.ext4", NULL, 0) < 0) {
        LOGE("需要 mkfs.ext4");
        return 1;
    }
    /* 估算大小:du -sb src * 1.2,最小 32MB */
    char script[1024];
    snprintf(script, sizeof(script),
             "sz=$(du -sb %s | awk '{print $1}'); "
             "sz=$((sz * 12 / 10 + 1048576)); "
             "[ $sz -lt 33554432 ] && sz=33554432; "
             "echo \"image size: $sz bytes\"; "
             "dd if=/dev/zero of=%s bs=1M count=$((sz / 1048576 + 1)) status=none; "
             "mkfs.ext4 -F -d %s %s >/dev/null",
             src, out, src, out);
    const char *cmd[] = { "sh", "-c", script, NULL };
    return emb_run(cmd, 1);
}

/* ============================ NFS exports 配置 ============================ */

static int sub_nfs_export(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools fs nfs-export <dir> [subnet]");
        return 1;
    }
    const char *dir = argv[2];
    const char *sub = (argc >= 4) ? argv[3] : "*";

    printf("# 把以下行追加到 /etc/exports,然后: exportfs -ra\n");
    printf("%s   %s(rw,sync,no_subtree_check,no_root_squash)\n",
           dir, sub);
    printf("\n# 客户端挂载命令:\n");
    printf("# mount -t nfs -o nolock <server-ip>:%s /mnt\n", dir);
    return 0;
}

/* ============================ TFTP 简易服务器 ============================ */

/* 这是一个极简的 read-only TFTP 服务器实现 (RFC 1350),
 * 支持 RRQ (读请求),用于嵌入式开发时给目标板推送内核/设备树。
 * 不支持写、不支持 options;支持 octet 模式。
 */
static int tftp_serve_one(const char *root, int sock)
{
    struct sockaddr_in cli;
    socklen_t clilen = sizeof(cli);
    unsigned char buf[4 + 512];
    ssize_t n = recvfrom(sock, buf, sizeof(buf), 0,
                         (struct sockaddr *)&cli, &clilen);
    if (n < 4) return -1;
    unsigned short op = (buf[0] << 8) | buf[1];
    if (op != 1) {  /* 仅 RRQ */
        /* 发送 error */
        unsigned char err[5] = {0, 5, 0, 4, 0};
        sendto(sock, err, 5, 0, (struct sockaddr *)&cli, clilen);
        return -1;
    }
    /* filename\0mode\0 */
    char *fname = (char *)&buf[2];
    size_t fnlen = strnlen(fname, n - 2);
    if (fnlen == 0 || 2 + fnlen + 1 >= (size_t)n)
        return -1;
    char *mode = fname + fnlen + 1;
    (void)mode; /* 总是 octet */

    /* 防止路径穿越 */
    if (strstr(fname, "..") != NULL) {
        unsigned char err[5] = {0, 5, 0, 2, 0};
        sendto(sock, err, 5, 0, (struct sockaddr *)&cli, clilen);
        LOGW("拒绝路径穿越请求: %s", fname);
        return -1;
    }
    char path[1024];
    snprintf(path, sizeof(path), "%s/%s", root, fname);
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        unsigned char err[5] = {0, 5, 0, 1, 0};
        sendto(sock, err, 5, 0, (struct sockaddr *)&cli, clilen);
        LOGW("文件不存在: %s", path);
        return -1;
    }
    LOGI("TFTP RRQ: %s from %s", fname, inet_ntoa(cli.sin_addr));

    unsigned short block = 1;
    char databuf[512];
    int timeout_count = 0;
    while (1) {
        ssize_t r = read(fd, databuf, sizeof(databuf));
        if (r < 0) {
            unsigned char err[5] = {0, 5, 0, 0, 0};
            sendto(sock, err, 5, 0, (struct sockaddr *)&cli, clilen);
            break;
        }
        /* 发送 DATA */
        unsigned char datahdr[4];
        datahdr[0] = 0; datahdr[1] = 3; /* DATA */
        datahdr[2] = (block >> 8) & 0xff;
        datahdr[3] = block & 0xff;

        struct iovec iov[2];
        iov[0].iov_base = datahdr; iov[0].iov_len = 4;
        iov[1].iov_base = databuf; iov[1].iov_len = r;
        struct msghdr msg = {0};
        msg.msg_name = &cli;
        msg.msg_namelen = clilen;
        msg.msg_iov = iov;
        msg.msg_iovlen = 2;
        if (sendmsg(sock, &msg, 0) < 0) {
            LOGW("sendmsg: %s", strerror(errno));
            break;
        }
        /* 等待 ACK */
        unsigned char ack[4];
        fd_set rfds;
        struct timeval tv = { .tv_sec = 5, .tv_usec = 0 };
        FD_ZERO(&rfds);
        FD_SET(sock, &rfds);
        int sel = select(sock + 1, &rfds, NULL, NULL, &tv);
        if (sel <= 0) {
            if (++timeout_count > 5) {
                LOGW("重传超时,放弃");
                break;
            }
            continue;
        }
        n = recvfrom(sock, ack, sizeof(ack), 0,
                     (struct sockaddr *)&cli, &clilen);
        if (n < 4) break;
        unsigned short a = (ack[2] << 8) | ack[3];
        if (a != block) {
            /* 旧 ACK,重传 */
            continue;
        }
        timeout_count = 0;
        if (r < 512) {
            /* 最后一块小于 512 字节,完成 */
            break;
        }
        ++block;
    }
    close(fd);
    return 0;
}

static int sub_tftp_serve(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools fs tftp-serve <root-dir> [port=69]");
        return 1;
    }
    const char *root = argv[2];
    int port = (argc >= 4) ? atoi(argv[3]) : 69;
    if (access(root, F_OK) != 0) {
        LOGE("根目录 %s 不存在", root);
        return 1;
    }

    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        LOGE("socket: %s", strerror(errno));
        return 1;
    }
    int one = 1;
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        LOGE("bind %d: %s (端口 <1024 需要 root)", port, strerror(errno));
        close(sock);
        return 1;
    }
    LOGI("TFTP 服务器启动,根目录 %s,UDP %d,按 Ctrl+C 退出", root, port);
    while (1) {
        tftp_serve_one(root, sock);
    }
    close(sock);
    return 0;
}

/* ============================ OTA ============================ */

static int sub_ota_check(int argc, char **argv)
{
    if (argc < 3) {
        LOGE("usage: embtools fs ota-check <rootfs-dir>");
        return 1;
    }
    const char *dir = argv[2];
    const char *need[] = {
        "/bin", "/sbin", "/usr", "/lib", "/etc", "/dev",
        "/proc", "/sys", "/var", "/tmp", "/boot", "/root"
    };
    int missing = 0;
    printf(COL_BOLD "检查 rootfs 结构: %s\n" COL_RESET, dir);
    for (size_t i = 0; i < sizeof(need)/sizeof(need[0]); ++i) {
        char p[1024];
        snprintf(p, sizeof(p), "%s%s", dir, need[i]);
        int ok = (access(p, F_OK) == 0);
        printf("  [%s] %s\n", ok ? COL_GREEN "OK" COL_RESET :
               COL_RED "MISS" COL_RESET, need[i]);
        if (!ok) ++missing;
    }
    /* 关键文件 */
    const char *files[] = { "/etc/inittab", "/etc/fstab", "/etc/passwd",
                            "/bin/sh", "/sbin/init", "/bin/mount" };
    printf(COL_BOLD "\n关键文件:\n" COL_RESET);
    for (size_t i = 0; i < sizeof(files)/sizeof(files[0]); ++i) {
        char p[1024];
        snprintf(p, sizeof(p), "%s%s", dir, files[i]);
        int ok = (access(p, F_OK) == 0);
        printf("  [%s] %s\n", ok ? COL_GREEN "OK" COL_RESET :
               COL_RED "MISS" COL_RESET, files[i]);
        if (!ok) ++missing;
    }
    if (missing)
        LOGW("共缺失 %d 项,请确认 rootfs 完整性", missing);
    else
        LOGI("rootfs 结构完整");
    return missing ? 1 : 0;
}

static int sub_ota_apply(int argc, char **argv)
{
    if (argc < 4) {
        LOGE("usage: embtools fs ota-apply <pkg.tar.gz> <dest-dir>");
        return 1;
    }
    const char *pkg = argv[2];
    const char *dst = argv[3];
    if (access(pkg, R_OK) != 0) {
        LOGE("OTA 包 %s 不可读", pkg);
        return 1;
    }
    if (access(dst, W_OK) != 0) {
        LOGE("目标 %s 不可写", dst);
        return 1;
    }
    confirm_write(dst);
    char script[1024];
    snprintf(script, sizeof(script),
             "tar -xvpzf %s -C %s", pkg, dst);
    const char *cmd[] = { "sh", "-c", script, NULL };
    int rc = emb_run(cmd, 1);
    if (rc == 0)
        LOGI("OTA 应用完成,请 sync 并重启");
    sync();
    return rc;
}

/* ============================ fs 命令分派 ============================ */

int cmd_fs(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stdout, "%s", emb_subcmds[3].help);
        return 1;
    }
    const char *sub = argv[1];
    if (strcmp(sub, "ls") == 0)         return sub_ls(argc, argv);
    if (strcmp(sub, "mount") == 0)      return sub_mount(argc, argv);
    if (strcmp(sub, "umount") == 0)     return sub_umount(argc, argv);
    if (strcmp(sub, "dd-iso") == 0)     return sub_dd_iso(argc, argv);
    if (strcmp(sub, "mkrootfs") == 0)   return sub_mkrootfs(argc, argv);
    if (strcmp(sub, "nfs-export") == 0) return sub_nfs_export(argc, argv);
    if (strcmp(sub, "tftp-serve") == 0) return sub_tftp_serve(argc, argv);
    if (strcmp(sub, "ota-check") == 0)  return sub_ota_check(argc, argv);
    if (strcmp(sub, "ota-apply") == 0)  return sub_ota_apply(argc, argv);

    LOGE("未知 fs 子命令: %s", sub);
    fprintf(stdout, "%s", emb_subcmds[3].help);
    return 1;
}
