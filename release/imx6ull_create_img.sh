#!/bin/bash
# * =====================================================
# * Copyright © hk. 2022-2025. All rights reserved.
# * File name  : imx6ull_create_img.sh
# * Author     : 苏木
# * Date       : 2024-11-13
# * ======================================================
##


BLACK="\033[1;30m"
RED='\033[1;31m'    # 红
GREEN='\033[1;32m'  # 绿
YELLOW='\033[1;33m' # 黄
BLUE='\033[1;34m'   # 蓝
PINK='\033[1;35m'   # 紫
CYAN='\033[1;36m'   # 青
WHITE='\033[1;37m'  # 白
CLS='\033[0m'       # 清除颜色

INFO="${GREEN}[INFO]${CLS}"
WARN="${YELLOW}[WARN]${CLS}"
ERR="${RED}[ERR ]${CLS}"

SCRIPT_NAME=${0#*/}
SCRIPT_CURRENT_PATH=${0%/*}
SCRIPT_ABSOLUTE_PATH=`cd $(dirname ${0}); pwd`
home=/home/sumu

SYSTEM_ENVIRONMENT_FILE=/etc/profile # 系统环境变量位置
USER_ENVIRONMENT_FILE=${home}/.bashrc
SOFTWARE_DIR_PATH=${home}/2software        # 软件安装目录
##======================================================

#根据当前时间取文件名
CURRENT_TIME=$(date +'%Y%m%d-%H%M%S')
LOOP_DEV=$(losetup -f)        # /dev/loop14
LOOP_DEV_NAME=${LOOP_DEV##*/} # loop14
IMG_NAME=imx6ull-${CURRENT_TIME}.img

#execute执行语句成功与否打印
function execute ()
{
    # echo $* # $*就是执行的命令
    $* >/dev/null
    if [ $? -ne 0 ]; then
        echo
        echo -e ${ERR}"执行 $*"
        echo
        exit 1
    fi
}

function img_create()
{
    #创建一个空的镜像文件
    echo -e ${INFO}"创建空的 ${IMG_NAME} 文件..."
    # dd if=/dev/zero of=imx6ull-sys.img bs=1024 count=102400 && sync
    sudo dd if=/dev/zero of=./$IMG_NAME bs=1024 count=102400 && sync
}

function img_part()
{
    #给镜像文件分区
    echo -e ${INFO}"对 ${IMG_NAME} 文件进行分区..."
    # sudo parted imx6ull-sys.img mklabel msdos
    # sudo parted imx6ull-sys.img mkpart primary fat32 2048s 133119s # s就表示扇区
    # sudo parted imx6ull-sys.img mkpart primary ext4 133120s 100%
    sudo parted ${IMG_NAME} mklabel msdos
    sudo parted ${IMG_NAME} mkpart primary fat32 1M 64M
    sudo parted ${IMG_NAME} mkpart primary ext4 64M 100%
    sudo parted ${IMG_NAME} print
    sync
}

function img_file_virtual_to_block_device()
{
    echo -e ${INFO}"将 ${IMG_NAME} 文件虚拟成块设备 ${LOOP_DEV}..."
    #loopdev=$(losetup -f) 可以通过losetup -f指令查看哪个loop空闲
    #将映像文件挂接到loopX中去，如果loop0空闲，loop0可以看作是磁盘设备，其存储区域就是所挂载的镜像文件
    #这样就把img文件映射为一个磁盘设备了，可以通过设备的方式对它进行访问了
    # sudo losetup /dev/loop13 imx6ull-sys.img
    sudo losetup ${LOOP_DEV} ${IMG_NAME}
    #使用kpartx来装载镜像文件，识别该硬盘的分区表。装载之后，就可以在/dev/mapper/目录下看到两个loopXpY的文件了。
    # sudo kpartx -av /dev/loop13
    sudo kpartx -av ${LOOP_DEV}
}

function img_format_partition()
{
    #对两个分区进行格式化
    echo -e ${INFO}"将 ${IMG_NAME} 分区格式化..."
    ls /dev/mapper/${LOOP_DEV_NAME}*
    # sudo mkfs.vfat -F 32 /dev/mapper/loop13p1
    # sudo mkfs.ext4 /dev/mapper/loop13p2
    sudo mkfs.vfat -F 32 /dev/mapper/${LOOP_DEV_NAME}p1
    sudo mkfs.ext4 /dev/mapper/${LOOP_DEV_NAME}p2
    sudo parted ${IMG_NAME} print
    sync
}

function img_download_uboot()
{
    echo -e ${INFO}"烧写uboot到 ${IMG_NAME} 分区..."
    # sudo dd if=u-boot-dtb.imx of=imx6ull-sys.img bs=1024 seek=1 conv=fsync
    sudo dd if=u-boot-dtb.imx of=${IMG_NAME} bs=1k seek=1 conv=notrunc,sync
}

function img_download_kernel_dtb_rootfs()
{
    echo -e ${INFO}"挂载 ${IMG_NAME} 分区..."
    if [ ! -e BOOT ];then
        mkdir -pv BOOT
    fi

    if [ ! -e rootfs ];then
        mkdir -pv  rootfs
    fi
    sudo mount /dev/mapper/${LOOP_DEV_NAME}p1 BOOT
    sudo mount  /dev/mapper/${LOOP_DEV_NAME}p2 rootfs

    echo -e ${INFO}"拷贝文件到 ${IMG_NAME} 分区..."
    sudo cp zImage BOOT
    sudo cp imx6ull-alpha-emmc.dtb BOOT

    sudo tar jxf rootfs.tar.bz2 -C rootfs
    cd rootfs
    sudo tar xf rootfs.tar
    cd ..

    echo -e ${INFO}"卸载 ${IMG_NAME} 分区..."
    sudo umount BOOT
    sudo umount rootfs
    sync
}

function img_loop_dev_remove()
{
    echo -e ${INFO}"卸载 ${IMG_NAME} 循环设备${LOOP_DEV}..."
    sudo kpartx -dv ${LOOP_DEV}
    sudo losetup -d ${LOOP_DEV}
}
sd_device=/dev/sdc
sd_part=()
sd_node=()
sd_mount_path_prefix=${home}/sdtmp/sd_
sd_mount_path=${sd_mount_path_prefix}${sd_node[0]} # ~/tmp/sd_sdc1
sd_part_num=0

function sd_part_info_get()
{
    local i=0;
    for tmp in `ls ${sd_device}? 2>/dev/null` # ls访问不到的时候会显示错误，这里重定向一下
        do
            sd_part[$i]=${tmp}
            sd_node[$i]=${tmp##*/}
            ((i++))
        done
    sd_part_num=$i
    echo -e ${INFO}"${sd_device}共有${sd_part_num}个分区：${sd_part[@]}"
}
# 获取点节点名称以及分区信息
function sd_get_device()
{
    cat /proc/partitions
    while true
        do
            read -p "Please Input the card ID [a~z]: (Input 'exit' for quit):" dev_index
            case $dev_index in  
                [[:lower:]]) 
                    break
                    ;;
                exit) 
                    exit 0
                    ;;
                * ) 
                    echo -e "${RED}Invalid parameter!${cls}"
                    echo -e "${RED}The parameter should be between a~z, enter 'exit' to quit.${cls}"
                    echo -e "${GREEN}Usage: If the SD card device corresponds to /dev/sdd, enter d ${cls}"
                    continue
                ;;
            esac  
        done

    sd_device=/dev/sd${dev_index}
    #判断选择的块设备是否存在及是否是一个块设备
    if [ ! -b ${sd_device} ]; then
        echo ${ERR}"${sd_device}不是一个块设备文件..."
        exit 1
    fi
    #这里防止选错设备，否则会影响Ubuntu系统的启动
    if [ ${sd_device} = '/dev/sda' ];then
        echo -e ${ERR}"请不要选择sda设备，/dev/sda通常是您的Ubuntu硬盘!继续操作你的系统将会受到影响！脚本已自动退出"
        exit 1 
    fi
    echo -e ${INFO}"选择的SD卡节点为：${PINK}${sd_device}${CLS} ......"
    # 获取一次分区信息
    sd_part_info_get
}

# 清空前1M的空间
function sd_clear()
{
    sd_get_device
    read -p "是否清空SD卡前1M空间:" ret
    if [ "${ret}" != "n" ];then
        echo -e ${INFO}"sudo dd if=/dev/zero of=${sd_device} bs=1024 count=1024"
        # sudo dd if=/dev/zero of=/dev/sdc bs=1024 count=1024
        execute "sudo dd if=/dev/zero of=${sd_device} bs=1024 count=1024"
    fi
}

# 这里的这个函数获取img文件名会出问题，这里不用
function sd_download()
{
    sd_get_device
    echo -e ${INFO}"烧写${IMG_NAME}到SD卡"
    sudo dd if=${IMG_NAME} of=${sd_device} conv=fsync
    echo -e ${INFO}"烧写${IMG_NAME}完毕"
}

function echo_menu()
{
    echo "================================================="
	echo -e "${GREEN}               build project ${CLS}"
	echo -e "${GREEN}                by @苏木    ${CLS}"
	echo "================================================="
    echo -e "${PINK}current path         :$(pwd)${CLS}"
    echo -e "${PINK}SCRIPT_CURRENT_PATH  :${SCRIPT_CURRENT_PATH}${CLS}"
    echo ""
    echo -e "*${GREEN} [0] 生成一个img文件${IMG_NAME}${CLS}"
    echo -e "* [1] 清空SD卡前1M空间"
    echo -e "* [2] 烧写到SD卡"
    echo "================================================="
}

function img_pack()
{
    img_create
    img_part
    img_file_virtual_to_block_device
    img_format_partition
    img_download_uboot
    img_download_kernel_dtb_rootfs
    img_loop_dev_remove
    echo -e ${INFO}"${IMG_NAME} 制作完毕。"
    du -sh ${IMG_NAME}
}
function func_process()
{
	read -p "请选择功能,默认选择0:" choose
	case "${choose}" in
		"0") img_pack;;
		"1") sd_clear;;
		"2") sd_download;;
		*) img_pack;;
	esac
}

echo_menu
func_process


