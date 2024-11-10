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
USER_ENVIRONMENT_FILE=~/.bashrc
SOFTWARE_DIR_PATH=~/2software        # 软件安装目录
##======================================================
imx6ull_release_path=~/7Linux/imx6ull-alpha-release/release
uboot_img_name=(u-boot-dtb.bin u-boot-dtb.imx)
linux_img_name=zImage
linux_dtb_name=imx6ull-alpha-emmc.dtb
buildroot_rootfs_name=rootfs.tar.bz2

sd_device=/dev/sdc
sd_part=()
sd_node=()
sd_part_num=0

function sd_part_info_get()
{
    for tmp in `ls ${sd_device}?`
        do
            sd_part[sd_part_num]=${tmp}
            sd_node[sd_part_num]=${tmp##*/}
            ((sd_part_num++))
        done
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

sd_get_device