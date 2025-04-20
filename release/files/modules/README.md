- files/modules

```shell
files/
├─...
├─modules
│      modules.tar.bz2
├─...
```

- modules.tar.bz2 结构如下

```shell
# 解压命令 tar -xvf modules.tar.bz2 -C rmodules
# modules 目录将会是：
modules/
├─5.15.0-122-generic   # 这个可以通过 uname -r 命令获得
│       kernel         # 用于分类存放不同功能的内核模块（如驱动、文件系统等）‌
│       modules.dep    # Linux内核模块依赖关系文件
│       modules.alias
│       modules.symbols
│       ...
```

目录详细说明：
3.modules目录下存放的是内核模块压缩包

