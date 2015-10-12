PREFIX ?= /usr/local

CC = "$(shell xcrun --sdk macosx --find clang)"
SDK = "$(shell xcrun --sdk macosx --show-sdk-path)"
INSTALL = $(shell xcrun --find install) -c

clang-compilation-database-tool: clang-compilation-database-tool.m
	$(CC) -isysroot $(SDK) -ObjC -fobjc-arc -framework Foundation -o clang-compilation-database-tool clang-compilation-database-tool.m

all: clang-compilation-database-tool

install: all
	$(INSTALL) clang-compilation-database-tool $(PREFIX)/bin
