# clang-compilation-database-tool

A tool that can be used to generate [Clang Compilation DBs](http://clang.llvm.org/docs/JSONCompilationDatabase.html)
from Xcode.

Given a compilation command (in the format that Xcode uses) the `dump` command will generate a `.compilation-db-unit`
file next to the object file. The `collect` command will find all these `*.compilation-db-unit` files and write a full
compilation database to `STDOUT`.

### Installation

```
$ git clone https://github.com/alloy/clang-compilation-database-tool.git
$ cd clang-compilation-database-tool
$ make install [PREFIX=/usr/local]
```

### Xcode integration

Create a shell script that contains the following:

```shell
#!/bin/sh

CLANG="${DT_TOOLCHAIN_DIR}/usr/bin/clang"

if type -p clang-compilation-database-tool > /dev/null 2>&1; then
  clang-compilation-database-tool dump ${CLANG} $@
fi

exec ${CLANG} $@
```

And make it executable:

```
$ chmod +x clang-with-compilation-db
```

Then add a ‘User-Defined Setting’ to your Xcode target’s build settings with the key `CC` and the value
`clang-with-compilation-db`.

----

Add a ‘Run Script Phase’ to your Xcode target and have it contain something like the following:

```shell
if type -p clang-compilation-database-tool > /dev/null 2>&1; then
  clang-compilation-database-tool collect "${OBJECT_FILE_DIR_normal}" > "${SRCROOT}/compile_commands.json"
fi
```

----

This generate a `compile_commands.json` file in the source root after every build, but only if the
`clang-compilation-database-tool` tool is available.

You should perform a clean build once you’ve got this setup in order to get a full compilation database.
