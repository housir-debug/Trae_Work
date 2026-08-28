# embtools - 嵌入式 Linux 工程师助手工具

`embtools` 是一款用 **C 语言** 实现的命令行综合工具集,面向嵌入式 Linux 软件工程师,
覆盖日常开发、调试、部署的四大场景:

| 模块  | 覆盖范围                                              |
| ----- | ----------------------------------------------------- |
| build | 交叉编译与构建管理(工具链、内核、模块、Yocto、Buildroot)|
| hw    | 设备树与硬件调试(GPIO/I2C/SPI/UART/devmem)            |
| sys   | 系统监控与性能分析(CPU/mem/disk/net/ps/perf/ftrace)   |
| fs    | 文件系统与部署(ls/mount/dd-iso/mkrootfs/NFS/TFTP/OTA)|

特点:
- 单一可执行文件,无运行时依赖(只依赖 glibc 和系统已存在的辅助工具如 `dtc`/`i2cdetect`/`mkfs.ext4`)
- 既可在开发主机上运行,也可部署到目标板上(支持交叉编译)
- 所有命令均会回显实际执行的 shell 命令(`$ ...`),便于审计与脚本化

## 构建

```sh
make            # 默认 -O2 -Wall
make check      # 简单冒烟测试
sudo make install PREFIX=/usr/local
```

### 交叉编译到目标板

```sh
make CC=arm-linux-gnueabihf-gcc
```

## 使用速查

```sh
embtools -v                              # 版本
embtools help                            # 总览
embtools help hw                         # 查看 hw 子命令

# build -----------------------------------------------------------------
embtools build toolchain-info arm-linux-gnueabihf-
embtools build kernel-config   /path/to/linux
embtools build kernel-build    /path/to/linux zImage
embtools build module-build    /path/to/my-drv [--kernel /path/to/linux]
embtools build yocto-layers    /path/to/poky
embtools build yocto-recipe    /path/to/poky linux-raspberrypi
embtools build buildroot-info  /path/to/buildroot

# hw --------------------------------------------------------------------
embtools hw dtc-decompile board.dtb       # dtb -> dts
embtools hw dtc-compile  board.dts        # dts -> dtb
embtools hw gpio list
embtools hw gpio export 17 out && embtools hw gpio set 17 1
embtools hw gpio get 17 18 19            # 多个 GPIO
embtools hw i2c detect 0
embtools hw i2c dump 0 0x50
embtools hw i2c set 0 0x50 0x12 0x34
embtools hw spi dev spidev0.0
embtools hw uart /dev/ttyUSB0 115200      # 按 Ctrl+] 退出
embtools hw reg read 0x40020000 4          # devmem,连续读 4 个寄存器
embtools hw reg write 0x40020000 0x55

# sys -------------------------------------------------------------------
embtools sys cpu
embtools sys mem
embtools sys disk
embtools sys net
embtools sys ps bash
embtools sys top 5 cpu
embtools sys top 10 mem
embtools sys log 100
embtools sys uptime
embtools sys temp
embtools sys perf record ./my_app
embtools sys perf report perf.data
embtools sys trace sched:sched_switch

# fs --------------------------------------------------------------------
embtools fs ls                            # 列出块设备与分区
embtools fs mount /dev/sdb1 /mnt
embtools fs umount /mnt
embtools fs dd-iso sdcard.img /dev/sdb 4M  # 烧写镜像(5 秒确认)
embtools fs mkrootfs ./rootfs rootfs.ext4 ext4
embtools fs mkrootfs ./rootfs rootfs.sqfs squashfs
embtools fs nfs-export /opt/nfsroot 192.168.1.0/24
embtools fs tftp-serve /var/lib/tftpboot 69   # 内置只读 TFTP 服务器
embtools fs ota-check ./rootfs
embtools fs ota-apply update.tar.gz /mnt/root
```

## 全局选项

- `--no-color` 关闭彩色输出
- `-d, --debug` 开启调试日志

## 模块设计

```
embtools/
├── embtools.h       # 公共类型 / 工具函数声明 / 子命令表声明
├── common.c         # 工具函数实现 + emb_usage()
├── main.c           # 入口、命令分发、help/version
├── cmd_build.c     # 交叉编译与构建管理
├── cmd_hw.c         # 设备树与硬件调试
├── cmd_sys.c        # 系统监控与性能分析
├── cmd_fs.c         # 文件系统与部署(含 RFC1350 只读 TFTP)
└── Makefile
```

新增模块只需:
1. 实现 `int cmd_xxx(int argc, char **argv)`
2. 在 `emb_subcmds[]`(main.c) 注册一项,即可获得 help 文本与命令分发

## 权限说明

部分命令需要 root:
- `hw gpio export/unexport/set`(写 `/sys/class/gpio/export`)
- `hw reg read/write`(`devmem` / `/dev/mem`)
- `fs dd-iso / mkrootfs / mount / umount / ota-apply`
- `fs tftp-serve`(监听 < 1024 端口)
- `sys perf record / trace`(写 tracefs)

## 许可

按"原样"提供,使用者自负风险。烧写命令均带 5 秒确认窗口。
