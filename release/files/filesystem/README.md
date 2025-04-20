- files/filesystem

```shell
files/
├─...
├─filesystem
│      rootfs.tar.bz2
├─...
```

- rootfs.tar.bz2 结构如下

```shell
# 解压命令 tar -xvf rootfs.tar.bz2 -C rootfs
# rootfs目录将会是：
bin  boot  dev  etc  home  lib  media  mnt  opt  proc  run  sbin  sys  tmp  usr  var
```

目录详细说明：
2.filesystem目录下存放文件系统压缩包

