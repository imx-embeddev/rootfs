脚本烧写方式，可以拷贝files文件夹执行脚本直接烧写

- files目录结构如下

```shell
files/
│  imx6mkemmcboot.sh
│  imx6mknandboot.sh
│  imx6mksdboot.sh
│  README.md
│
├─boot
│      imx6ull-14x14-emmc-4.3-800x480-c.dtb
│      u-boot-imx6ull-14x14-ddr512-emmc.imx
│      zImage
│
├─filesystem
│      rootfs.tar.bz2
│
└─modules
        modules.tar.bz2
```

- 目录详细说明：

（1）boot目录下存放设备树、内核与U-boot。

（2）filesystem目录下存放文件系统压缩包

（3）modules目录下存放的是内核模块压缩包

- 制卡脚本说明:

（1）使用imx6mksdboot.sh制作的是从SD卡启动系统，复制整个files制卡工具包到Ubuntu，用读卡器插入SD卡，连接到Ubuntu上，执行该脚本进行烧写，执行脚本需要选择参数。

（2）使用imx6mkemmcboot.sh制作的是从eMMC启动系统，使用含eMMC版本的板卡，从SD卡启动系统后，复制整个files制卡工具包到文件系统目录下，执行该脚本进行烧写，执行脚本需要选择参数。

（3）使用imx6mknandboot.sh制作的是从NAND FLASH启动系统，使用含NAND FLASH版本的板卡，从SD卡启动系统后，复制整个files制卡工具包到文件系统目录下，执行该脚本进行烧写，执行脚本需要选择参数。

