# Makefile for embtools - 嵌入式 Linux 工程师助手工具
#
# 目标:
#   make / make all   - 构建主程序
#   make clean        - 清理
#   make install      - 安装到 $(DESTDIR)$(PREFIX)/bin
#   make check        - 简单冒烟测试(运行 embtools help / -v)

CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra -Wno-unused-parameter -std=gnu11 \
           -Wno-format-truncation -Wno-stringop-truncation
LDFLAGS ?=
LIBS    ?=
PREFIX  ?= /usr/local
DESTDIR ?=

PROG    := embtools
SRCS    := main.c common.c cmd_build.c cmd_hw.c cmd_sys.c cmd_fs.c
OBJS    := $(SRCS:.c=.o)
DEPS    := $(OBJS:.o=.d)

# 自动生成头文件依赖
DEPFLAGS = -MMD -MP

.PHONY: all clean install check

all: $(PROG)

$(PROG): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(LIBS)

%.o: %.c embtools.h
	$(CC) $(DEPFLAGS) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJS) $(DEPS) $(PROG)

install: $(PROG)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 0755 $(PROG) $(DESTDIR)$(PREFIX)/bin/

check: $(PROG)
	@echo "=== version ==="
	./$(PROG) -v
	@echo "=== help ==="
	./$(PROG) help | head -n 10
	@echo "=== help build ==="
	./$(PROG) help build | head -n 5

-include $(DEPS)
