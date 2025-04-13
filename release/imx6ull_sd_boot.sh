#!/bin/bash
# * =====================================================
# * Copyright © hk. 2022-2025. All rights reserved.
# * File name  : imx6ull_sd_boot.sh
# * Author     : 苏木
# * Date       : 2024-11-10
# * ======================================================
##
##======================================================
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

SYSTEM_ENVIRONMENT_FILE=/etc/profile # 系统环境变量位置
USER_ENVIRONMENT_FILE=${HOME}/.bashrc
SOFTWARE_DIR_PATH=${HOME}/2software        # 软件安装目录
##======================================================

imx6ull_release_path=${SCRIPT_ABSOLUTE_PATH}
uboot_img_name=(u-boot-dtb.bin u-boot-dtb.imx)
linux_img_name=zImage
linux_dtb_name=imx6ull-alpha-emmc.dtb
buildroot_rootfs_name=rootfs.tar.bz2

sd_device=/dev/sdc
sd_part=()
sd_node=()
sd_mount_path_prefix=${HOME}/sdtmp/sd_
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

# 卸载所有的sdc节点
function sd_umount_node()
{
    # 格式化前要卸载
    for i in "${sd_part[@]}"; do
        echo -e ${INFO}"卸载 device '$i'"
        umount $i 2>/dev/null
    done
}

# 清空前1M的空间
function sd_clear()
{
    read -p "是否清空SD卡前1M空间:" ret
    if [ "${ret}" != "n" ];then
        echo -e ${INFO}"sudo dd if=/dev/zero of=${sd_device} bs=1024 count=1024"
        # sudo dd if=/dev/zero of=/dev/sdc bs=1024 count=1024
        execute "dd if=/dev/zero of=${sd_device} bs=1024 count=1024"
    fi
}

#第一个分区为64M用来存放设备树与内核镜像文件，因为设备树与内核都比较小，不需要太大的空间
#第二个分区为SD卡的总大小-64M，用来存放文件系统
function sd_partition()
{
    echo -e ${INFO}"开始对 ${sd_device} 分区..."
    cat << END | sudo fdisk -H 255 -S 63 ${sd_device}
    n
    p
    1

    +64M
    n
    p
    2


    t
    1
    c
    a
    1
    p
    w 
END
    sleep 1
    echo -e ${INFO}"${sd_device} 分区完毕..."
    # 获取一次分区信息
    sd_part_info_get
}

function sd_partition_mkfs()
{
    echo -e ${INFO}"格式化${sd_device}的分区${sd_part[@]} ..."
    for tmp in ${sd_part[@]}; do
        if [ -b ${tmp} ] && [ "${tmp}" == "${sd_device}1" ];then # /dev/sdc1的处理
            echo -e ${INFO}"${tmp}是一个块设备，开始格式化${sd_device}1 ..."
            mkfs.vfat -F 32 -n "BOOT" ${sd_device}1
        elif [ -b ${tmp} ] && [ "${tmp}" == "${sd_device}2" ];then # /dev/sdc2的处理
            echo -e ${INFO}"${tmp}是一个块设备，开始格式化${sd_device}2 ..."
            mkfs.ext4 -F -L "rootfs" ${sd_device}2
        else
            echo -e ${WARN}"${tmp}暂不处理 ..."
        fi
    done
    echo -e ${INFO}"${sd_device}的分区${sd_part[@]}格式化完毕 ..."
}

function sd_dowwnload_uboot()
{
    cd ${imx6ull_release_path}
    ls -alh

    echo -e ${INFO}"正在烧写${uboot_img_name[1]}到 ${sd_device}..."
    execute "dd if=${uboot_img_name[1]} of=${sd_device} bs=1024 seek=1 conv=fsync"
    sync
    echo -e ${INFO}"烧写${uboot_img_name}到${sd_device}完成！"

}

function sd_dowwnload_kernel_dtbs()
{

    sd_mount_path=${sd_mount_path_prefix}${sd_node[0]}
    local dev=${sd_part[0]}
    echo -e ${INFO}"拷贝内核和设备树到 ${PINK}${dev}${CLS} ..."
    echo -e ${INFO}"挂载目录名为${sd_mount_path}"
    
    cd ${imx6ull_release_path}
    ls -alh

    # sd_node[0]= /dev/sdc1
    if [ ! -d "${sd_mount_path}" ];then
        echo -e ${WARN}"${sd_mount_path}不存在，开始创建..."
        execute "mkdir -pv ${sd_mount_path}"
    fi
    # 等待设备可用
    while [ ! -e ${dev} ]; do
        sleep 1
        echo "wait for ${dev} appear"
    done

    echo -e ${INFO}"挂载${dev}到${sd_mount_path} ..."
    execute "mount ${dev} ${sd_mount_path}"

    echo -e ${INFO}"正在拷贝${linux_img_name}到 ${sd_mount_path}..."
    execute "cp -r ${linux_img_name} ${sd_mount_path}"
    echo -e ${INFO}"正在拷贝${linux_dtb_name}到 ${sd_mount_path}..."
    execute "cp -r ${linux_dtb_name} ${sd_mount_path}"
    sync
    echo -e ${INFO}"复制设备树与内核到 ${sd_mount_path} 完成，${dev}中文件如下："
    ls  ${sd_mount_path} -alh
    
    echo -e ${INFO}"卸载 ${dev} ..."
    execute "umount ${dev}"
    sleep 1

    rm -rvf ${sd_mount_path}
    echo -e ${INFO}"${dev} 分区烧写完毕。"
}

function sd_dowwnload_rootfs()
{

    sd_mount_path=${sd_mount_path_prefix}${sd_node[1]}
    local dev=${sd_part[1]}
    echo -e ${INFO}"拷贝根文件系统到 ${PINK}${dev}${CLS} ..."
    echo -e ${INFO}"挂载目录名为${sd_mount_path}"
    
    cd ${imx6ull_release_path}
    ls -alh

    # sd_node[0]= /dev/sdc1
    if [ ! -d "${sd_mount_path}" ];then
        echo -e ${WARN}"${sd_mount_path}不存在，开始创建..."
        execute "mkdir -pv ${sd_mount_path}"
    fi
    # 等待设备可用
    while [ ! -e ${dev} ]; do
        sleep 1
        echo "wait for ${dev} appear"
    done

    echo -e ${INFO}"挂载${dev}到${sd_mount_path} ..."
    execute "mount ${dev} ${sd_mount_path}"

    echo -e ${INFO}"正在拷贝${buildroot_rootfs_name}到 ${sd_mount_path}..."
    execute "cp -r ${buildroot_rootfs_name} ${sd_mount_path}"
    sync

    cd ${sd_mount_path}
    ls  ${sd_mount_path} -a
    echo -e ${INFO}"开始解压 ${buildroot_rootfs_name} ..."
    execute "tar jxf ${buildroot_rootfs_name}"
    execute "tar xf ${buildroot_rootfs_name%.*}"
    echo -e ${INFO}"${buildroot_rootfs_name} 解压完毕，目录中文件如下:"
    ls  ${sd_mount_path} -a
    sync

    cd ${imx6ull_release_path}
    echo -e ${INFO}"卸载 ${dev} ..."
    execute "umount ${dev}"
    sleep 1

    rm -rvf ${sd_mount_path}
    echo -e ${INFO}"${dev} 分区烧写完毕。"
}

# 关闭ext4分区的journal日志功能
# 否则挂载根文件系统会失败
# ubuntu内核版本：5.15.0-122-generic
# nxp 内核版本：4.19.71
function sd_remove_ext4_journal()
{
    local dev=${sd_part[1]}
    echo -e ${INFO}"要处理的是根文件系统分区 ${PINK}${dev}${CLS} ..."

    # 查看分区特性
    tune2fs -l ${dev} | grep feature
    
    # 卸载分区
    umount ${dev} 2>/dev/null

    # 修改分区日志
    tune2fs -O ^has_journal ${dev}

    # 确认分区特性
    tune2fs -l ${dev} | grep feature
    echo -e ${INFO}"${dev} 分区journal日志处理完毕。"
}

function echo_menu()
{
    sd_get_device  # 最开始要先获取sd卡信息
    sd_umount_node # 然后卸载所有分区
    echo "================================================="
	echo -e "${GREEN}               build project ${CLS}"
	echo -e "${GREEN}                by @苏木    ${CLS}"
	echo "================================================="
    echo -e "${PINK}current path         :$(pwd)${CLS}"
    echo -e "${PINK}SCRIPT_CURRENT_PATH  :${SCRIPT_CURRENT_PATH}${CLS}"
    echo ""
    echo -e "*${GREEN} [0] 拷贝相关文件${CLS}"
    echo -e "* [1] 清空SD卡前1M空间"
    echo -e "* [2] 对SD卡进行分区"
    echo -e "* [3] 对SD分区进行格式化"
    echo -e "* [4] 烧写uboot到sd卡分区0"
    echo -e "* [5] 烧写内核和设备树到sd卡分区1"
    echo -e "* [6] 烧写根文件系统到sd卡分区2"
    echo -e "* [7] 移除ext4分区的has_journal特性"
    echo "================================================="
}

function sd_boot()
{
    sd_clear
    sd_partition
    sd_partition_mkfs
    sd_dowwnload_uboot
    sd_dowwnload_kernel_dtbs
    sd_dowwnload_rootfs
    sd_remove_ext4_journal
}
function func_process()
{
	read -p "请选择功能,默认选择0:" choose
	case "${choose}" in
		"0") sd_boot;;
		"1") sd_clear;;
		"2") sd_partition;;
		"3") sd_partition_mkfs;;
		"4") sd_dowwnload_uboot;;
        "5") sd_dowwnload_kernel_dtbs;;
        "6") sd_dowwnload_rootfs;;
        "7") sd_remove_ext4_journal;;
		*) sd_boot;;
	esac
}

echo_menu
func_process
