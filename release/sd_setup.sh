#!/bin/bash
# * =====================================================
# * Copyright © hk. 2022-2025. All rights reserved.
# * File name  : sd_setup.sh
# * Author     : 苏木
# * Date       : 2025-04-20
# * ======================================================
##
# 颜色和日志标识
# ========================================================
# |  ---  | 黑色  | 红色 |  绿色 |  黄色 | 蓝色 |  洋红 | 青色 | 白色  |
# | 前景色 |  30  |  31  |  32  |  33  |  34  |  35  |  35  |  37  |
# | 背景色 |  40  |  41  |  42  |  43  |  44  |  45  |  46  |  47  |
BLACK="\033[1;30m"
RED='\033[1;31m'    # 红
GREEN='\033[1;32m'  # 绿
YELLOW='\033[1;33m' # 黄
BLUE='\033[1;34m'   # 蓝
PINK='\033[1;35m'   # 紫
CYAN='\033[1;36m'   # 青
WHITE='\033[1;37m'  # 白
CLS='\033[0m'       # 清除颜色

INFO="${GREEN}INFO: ${CLS}"
WARN="${YELLOW}WARN: ${CLS}"
ERROR="${RED}ERROR: ${CLS}"

# 脚本和工程路径
# ========================================================
SCRIPT_NAME=${0#*/}
SCRIPT_CURRENT_PATH=${0%/*}
SCRIPT_ABSOLUTE_PATH=`cd $(dirname ${0}); pwd`
PROJECT_ROOT=${SCRIPT_ABSOLUTE_PATH} # 工程的源码目录，一定要和编译脚本是同一个目录
SOFTWARE_DIR_PATH=~/2software        # 软件安装目录
TFTP_DIR=~/3tftp
NFS_DIR=~/4nfs
CPUS=$(($(nproc)-1))                 # 使用总核心数-1来多线程编译
# 可用的emoji符号
# ========================================================
function usage_emoji()
{
    echo -e "⚠️ ✅ ❌ 🚩 📁 🕣️"
}

# 时间计算
# ========================================================
TIME_START=
TIME_END=

function get_start_time()
{
	TIME_START=$(date +'%Y-%m-%d %H:%M:%S')
}

function get_end_time()
{
	TIME_END=$(date +'%Y-%m-%d %H:%M:%S')
}

function get_execute_time()
{
	start_seconds=$(date --date="$TIME_START" +%s);
	end_seconds=$(date --date="$TIME_END" +%s);
	duration=`echo $(($(date +%s -d "${TIME_END}") - $(date +%s -d "${TIME_START}"))) | awk '{t=split("60 s 60 m 24 h 999 d",a);for(n=1;n<t;n+=2){if($1==0)break;s=$1%a[n]a[n+1]s;$1=int($1/a[n])}print s}'`
	echo "===*** 🕣️ 运行时间：$((end_seconds-start_seconds))s,time diff: ${duration} ***==="
}

function time_count_down
{
    for i in {3..0}
    do     

        echo -ne "${INFO}after ${i} is end!!!"
        echo -ne "\r\r"        # echo -e 处理特殊字符  \r 光标移至行首，但不换行
        sleep 1
    done
    echo "" # 打印一个空行，防止出现混乱
}

function get_run_time_demo()
{
    get_start_time
    time_count_down
    get_end_time
    get_execute_time
}

# 目录切换函数定义
# ========================================================
function cdi()
{
    if command -v pushd &>/dev/null; then
        # 压栈并切换
        pushd $1 >/dev/null || return 1
    else
        cd $1
    fi
}

function cdo()
{
    if command -v popd &>/dev/null; then
        # 弹出并恢复
        popd >/dev/null || return 1
    else
        cd -
    fi
}
# 临时目录生成与清理
# ========================================================
TMPDIR=()
function clean_up() 
{
    rm -rf "${TMPDIR[@]}"
}

# 注册清理函数，当脚本正常或者异常退出时都会执行
trap clean_up EXIT
# 开发环境信息
# ========================================================
function get_ubuntu_info()
{
    local kernel_version=$(uname -r) # 获取内核版本信息，-a选项会获得更详细的版本信息
    local ubuntu_version=$(lsb_release -ds) # 获取Ubuntu版本信息

    
    local ubuntu_ram_total=$(cat /proc/meminfo |grep 'MemTotal' |awk -F : '{print $2}' |sed 's/^[ \t]*//g')   # 获取Ubuntu RAM大小
    local ubuntu_swap_total=$(cat /proc/meminfo |grep 'SwapTotal' |awk -F : '{print $2}' |sed 's/^[ \t]*//g') # 获取Ubuntu 交换空间swap大小
    #local ubuntu_disk=$(sudo fdisk -l |grep 'Disk' |awk -F , '{print $1}' | sed 's/Disk identifier.*//g' | sed '/^$/d') #显示硬盘，以及大小
    local ubuntu_cpu=$(grep 'model name' /proc/cpuinfo |uniq |awk -F : '{print $2}' |sed 's/^[ \t]*//g' |sed 's/ \+/ /g') #cpu型号
    local ubuntu_physical_id=$(grep 'physical id' /proc/cpuinfo |sort |uniq |wc -l) #物理cpu个数
    local ubuntu_cpu_cores=$(grep 'cpu cores' /proc/cpuinfo |uniq |awk -F : '{print $2}' |sed 's/^[ \t]*//g') #物理cpu内核数
    local ubuntu_processor=$(grep 'processor' /proc/cpuinfo |sort |uniq |wc -l) #逻辑cpu个数(线程数)
    local ubuntu_cpu_mode=$(getconf LONG_BIT) #查看CPU当前运行模式是64位还是32位

    # 打印结果
    echo -e "ubuntu: $ubuntu_version - $ubuntu_cpu_mode"
    echo -e "kernel: $kernel_version"
    echo -e "ram   : $ubuntu_ram_total"
    echo -e "swap  : $ubuntu_swap_total"
    echo -e "cpu   : $ubuntu_cpu,physical id is$ubuntu_physical_id,cores is $ubuntu_cpu_cores,processor is $ubuntu_processor"
}

# 本地虚拟机VMware开发环境信息
function get_dev_env_info()
{
    echo "Development environment: "
    echo "ubuntu : 20.04.2-64(1核12线程 16GB RAM,512GB SSD) arm"
    echo "VMware : VMware® Workstation 17 Pro 17.6.0 build-24238078"
    echo "Windows: "
    echo "          处理器 AMD Ryzen 7 5800H with Radeon Graphics 3.20 GHz 8核16线程"
    echo "          RAM	32.0 GB (31.9 GB 可用)"
    echo "          系统类型	64 位操作系统, 基于 x64 的处理器"
    echo "linux开发板原始系统组件版本:"
    echo "          uboot : v2019.04 https://github.com/nxp-imx/uboot-imx/releases/tag/rel_imx_4.19.35_1.1.0"
    echo "          kernel: v4.19.71 https://github.com/nxp-imx/linux-imx/releases/tag/v4.19.71"
    echo "          rootfs: buildroot-2023.05.1 https://buildroot.org/downloads/buildroot-2023.05.1.tar.gz"
    echo ""
    echo "x86_64-linux-gnu   : gcc version 9.4.0 (Ubuntu 9.4.0-1ubuntu1~20.04.2)"
    echo "arm-linux-gnueabihf:"
    echo "          arm-linux-gnueabihf-gcc 8.3.0"
    echo "          https://developer.arm.com/-/media/Files/downloads/gnu-a/8.3-2019.03/binrel/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf.tar.xz"
}

# 环境变量
# ========================================================
# Github Actions托管的linux服务器有以下用户级环境变量，系统级环境变量加上sudo好像也权限修改
# .bash_logout  当用户注销时，此文件将被读取，通常用于清理工作，如删除临时文件。
# .bashrc       此文件包含特定于 Bash Shell 的配置，如别名和函数。它在每次启动非登录 Shell 时被读取。
# .profile、.bash_profile 这两个文件位于用户的主目录下，用于设置特定用户的环境变量和启动程序。当用户登录时，
#                        根据 Shell 的类型和配置，这些文件中的一个或多个将被读取。
USER_ENV=(~/.bashrc ~/.profile ~/.bash_profile)
SYSENV=(/etc/profile) # 系统环境变量位置
ENV_FILE=("${USER_ENV[@]}" "${SYSENV[@]}")

function source_env_info()
{
    for temp in ${ENV_FILE[@]};
    do
        if [ -f ${temp} ]; then
            echo -e "${INFO}source ${temp}"
            source ${temp}
        fi
    done
}

# ========================================================
# sd卡启动盘制作相关
# ========================================================
USER_HOME=/home/sumu # 这个脚本会使用sudo执行，所以会切换到root用户，USER就会变成root，这里固定一下

# 脚本参数传入处理
# ========================================================
function usage()
{
	echo -e "================================================="
    echo -e "${PINK}sudo ./1.sh       : 根据菜单选择功能${CLS}"
    echo -e ""
    echo -e "================================================="
}
# 脚本运行参数处理
echo -e "${CYAN}There are $# parameters: $@ (\$1~\$$#)${CLS}"
while getopts "b:p:m:" arg #选项后面的冒号表示该选项需要参数
    do
        case ${arg} in
            b)
                if [ $OPTARG == "usage" ];then
                    echo -e "${INFO}▶ $OPTARG"
                    usage
                    exit 1
                fi
                ;;
            ?)  #当有不认识的选项的时候arg为?
                echo -e "${RED}unkonw argument...${CLS}"
                exit 1
                ;;
        esac
    done

# 功能实现
# ========================================================
# sd卡操作
SD_DEV=/dev/sdc     # 默认节点
SD_PART=()
SD_NODE=()
SD_PART_CNT=0

#execute执行语句成功与否打印
function execute ()
{
    # echo $* # $*就是执行的命令
    $* >/dev/null
    if [ $? -ne 0 ]; then
        echo
        echo -e "${RED}执行 $* 失败!${CLS}"
        echo
        exit 1
    fi
}

# 获取SD卡分区个数并记录
function sd_get_part()
{
    local i=0;
    for tmp in `ls ${SD_DEV}? 2>/dev/null` # ls访问不到的时候会显示错误，这里重定向一下
        do
            SD_PART[$i]=${tmp}
            SD_NODE[$i]=${tmp##*/}
            ((i++))
        done
    SD_PART_CNT=$i
    echo -e "${INFO}▶ ${SD_DEV}共有${SD_PART_CNT}个分区：[${PINK} ${SD_PART[@]} ${CLS}], SD_NODE=[${PINK} ${SD_NODE[@]} ${CLS}]"
}

# 获取点节点名称以及分区信息
function sd_get_device()
{
    echo -e "${INFO}▶ /proc/partitions 信息如下:"
    cat /proc/partitions | grep -v 'loop' # 可以排除loop设备
    # cat /proc/partitions
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
                    echo -e "${RED}Invalid parameter!${CLS}"
                    echo -e "${RED}The parameter should be between a~z, enter 'exit' to quit.${CLS}"
                    echo -e "${GREEN}Usage: If the SD card device corresponds to /dev/sdd, enter d ${CLS}"
                    continue
                ;;
            esac  
        done

    SD_DEV=/dev/sd${dev_index}
    #判断选择的块设备是否存在及是否是一个块设备
    if [ ! -b ${SD_DEV} ]; then
        echo -e "${RED}${SD_DEV}不是一个块设备文件...${CLS}"
        exit 1
    fi
    #这里防止选错设备，否则会影响Ubuntu系统的启动
    if [ ${SD_DEV} = '/dev/sda' ];then
        echo -e "${RED}请不要选择sda设备, /dev/sda通常是您的Ubuntu硬盘!继续操作你的系统将会受到影响！脚本已自动退出${CLS}"
        exit 1
    fi
    echo -e "${INFO}▶ 选择的SD卡节点为: ${PINK}${SD_DEV}${CLS} ......"
    # 获取一次分区信息
    sd_get_part
}

# 卸载所有的sdc节点
function sd_umount()
{
    # 格式化前要卸载
    for i in "${SD_PART[@]}"; do
        echo -e ${INFO}"▶ 卸载 device '$i'"
        umount $i 2>/dev/null
    done
}

# 清空前1M的空间,这里存放着分区信息，清空就相当于格式化，后面会重新分区
function sd_start1M_clean()
{
    read -p "⚠️  是否清空SD卡前1M空间(默认清空,不清空请输入 n):" ret
    if [ "${ret}" != "n" ];then
        echo -e "${INFO}▶ sudo dd if=/dev/zero of=${SD_DEV} bs=1024 count=1024"
        # sudo dd if=/dev/zero of=/dev/sdc bs=1024 count=1024
        execute "dd if=/dev/zero of=${SD_DEV} bs=1024 count=1024"
    fi
}

#第一个分区为64M用来存放设备树与内核镜像文件，因为设备树与内核都比较小，不需要太大的空间
#第二个分区为SD卡的总大小-64M，用来存放文件系统
function sd_partition()
{
    echo -e "${INFO}▶ 开始对 ${SD_DEV} 分区 ..."
    cat << END | fdisk -H 255 -S 63 ${SD_DEV}
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
    echo -e "${INFO}▶ ${SD_DEV} 分区完毕..."
    # 获取一次分区信息
    sd_get_part
}

# 格式化分区
function sd_partition_mkfs()
{
    echo -e "${INFO}▶ 格式化${SD_DEV}的分区${SD_PART[@]} ..."
    for tmp in ${SD_PART[@]}; 
    do
        if [ -b ${tmp} ] && [ "${tmp}" == "${SD_DEV}1" ];then # /dev/sdc1的处理
            echo -e "${INFO}▶ ${tmp}是一个块设备，开始格式化${SD_DEV}1 ..."
            mkfs.vfat -F 32 -n "BOOT" ${SD_DEV}1
        elif [ -b ${tmp} ] && [ "${tmp}" == "${SD_DEV}2" ];then # /dev/sdc2的处理
            echo -e "${INFO}▶ ${tmp}是一个块设备，开始格式化${SD_DEV}2 ..."
            mkfs.ext4 -F -L "rootfs" ${SD_DEV}2
        else
            echo -e "⚠️  ${tmp}暂不处理 ..."
        fi
    done
    echo -e "${INFO}▶ ${SD_DEV}的分区${SD_PART[@]}格式化完毕."
    # 检查lsblk命令是否存在
    if command -v lsblk >/dev/null 2>&1; then
        lsblk -e 7,11 -o NAME,MAJ:MIN,RM,RO,TYPE,LABEL,FSTYPE,SIZE,MOUNTPOINT
    fi
}

# 烧写uboot到sd卡
function download_uboot2sd()
{
    cdi ${PROJECT_ROOT}/files/boot
    local img=u-boot-dtb.imx
    local dev=${SD_DEV}
    echo ""
    echo -e "🚩 ===> function ${FUNCNAME[0]}"
    echo -e "${PINK}current path :$(pwd)${CLS}"
    echo -e "${PINK}img          :${img}${CLS}"
    echo -e "${PINK}dev          :${dev}${CLS}"

    echo -e "${INFO}▶ 当前目录文件如下:"
    ls -alh

    echo -e "${INFO}▶ 正在烧写 ${img} 到 ${SD_DEV}..."
    execute "dd if=${img} of=${SD_DEV} bs=1024 seek=1 conv=fsync"
    sync
    echo -e "✅ 烧写${img} 到 ${SD_DEV}完成！"
    cdo
}

# 拷贝kernel和设备树到sd卡
function download_kernel_dtb2sd()
{
    local img=zImage
    local dtb=imx6ull-alpha-emmc.dtb
    local dev=${SD_PART[0]}
    local sd_mount_dir=/tmp/${SD_NODE[0]}

    cdi ${PROJECT_ROOT}/files/boot
    echo ""
    echo -e "🚩 ===> function ${FUNCNAME[0]}"
    echo -e "${PINK}current path :$(pwd)${CLS}"
    echo -e "${PINK}img          :${img}${CLS}"
    echo -e "${PINK}dtb          :${dtb}${CLS}"
    echo -e "${PINK}dev          :${dev}${CLS}"

    echo -e "${INFO}▶ 当前目录文件如下:"
    ls -alh

    # 1. 挂载sdc1 sd_node[0]= /dev/sdc1
    # if [ ! -d "${sd_mount_dir}" ];then
    #     echo -e "⚠️   ${sd_mount_dir}不存在，开始创建..."
    #     execute "mkdir -pv ${sd_mount_dir}"
    # fi
    TMPDIR[0]=$(mktemp -d /tmp/sdc1.XXXXXX)
    sd_mount_dir=${TMPDIR[0]} # 这种方式创建的目录即便是执行失败也会自动清理
    # 2. 等待设备可用
    while [ ! -e ${dev} ]; do
        sleep 1
        echo "wait for ${dev} appear..."
    done

    # 3. 挂载分区 /dev/sdc1
    echo -e "${INFO}▶ 挂载 ${dev} 到 ${sd_mount_dir} ..."
    execute "mount ${dev} ${sd_mount_dir}"
    # 4. 拷贝文件
    # 4.1 kernel
    echo -e "${INFO}▶ 正在拷贝${img}到 ${sd_mount_dir}..."
    execute "cp -f ${img} ${sd_mount_dir}"
    # 4.1 dtb
    echo -e "${INFO}▶ 正在拷贝${dtb}到 ${sd_mount_dir}..."
    execute "cp -f ${dtb} ${sd_mount_dir}"

    # 5. 同步
    sync

    # 6. 查看目录文件情况
    echo -e "${INFO}▶ ${sd_mount_dir} 文件如下:"
    ls -alh ${sd_mount_dir}

    # 7. 卸载挂载分区
    echo -e "${INFO}▶ 卸载 ${dev} ..."
    execute "umount ${dev}"
    sleep 1
    # 8. 删除创建的目录
    rm -rvf ${sd_mount_dir}
    echo -e "✅ 烧写${img} ${dtb} 到 ${dev} 完成！"
    cdo
}

# 下载rootfs到sd卡
function download_rootfs2sd()
{
    local img=rootfs.tar.bz2
    local dev=${SD_PART[1]}
    local sd_mount_dir=/tmp/${SD_NODE[1]}

    cdi ${PROJECT_ROOT}/files/filesystem
    echo ""
    echo -e "🚩 ===> function ${FUNCNAME[0]}"
    echo -e "${PINK}current path :$(pwd)${CLS}"
    echo -e "${PINK}img          :${img}${CLS}"
    echo -e "${PINK}dev          :${dev}${CLS}"

    echo -e "${INFO}▶ 当前目录文件如下:"
    ls -alh

    # 1. 挂载sdc1 sd_node[1]= /dev/sdc2
    # if [ ! -d "${sd_mount_dir}" ];then
    #     echo -e "⚠️   ${sd_mount_dir}不存在，开始创建..."
    #     execute "mkdir -pv ${sd_mount_dir}"
    # fi
    TMPDIR[1]=$(mktemp -d /tmp/sdc2.XXXXXX)
    sd_mount_dir=${TMPDIR[1]} # 这种方式创建的目录即便是执行失败也会自动清理
    # 2. 等待设备可用
    while [ ! -e ${dev} ]; do
        sleep 1
        echo "wait for ${dev} appear..."
    done

    # 3. 挂载分区 /dev/sdc1
    echo -e "${INFO}▶ 挂载 ${dev} 到 ${sd_mount_dir} ..."
    execute "mount ${dev} ${sd_mount_dir}"
    # 4. 拷贝文件
    echo -e "${INFO}▶ 拷贝 ${img} 到 ${sd_mount_dir}..."
    execute "cp -f ${img} ${sd_mount_dir}"
    # 5. 解压压缩包
    echo -e "${INFO}▶ 解压 ${img} 到 ${sd_mount_dir}..."
    # 注意，这里需要把根文件系统直接解压到对应目录，
    # 挂载的时候uboot的bootargs可以设置为root=/dev/mmcblk0p2，
    # 而不能设置为root=/dev/mmcblk0p2/imx6ull-rootfs
    execute "tar jxf ${img} --strip-components=1 -C ${sd_mount_dir}"
    # execute "tar xf ${img%.*}"
    # 6. 同步
    sync
    # 7. 查看目录文件情况
    echo -e "${INFO}▶ ${sd_mount_dir} 文件如下:"
    ls -a ${sd_mount_dir}

    # 8. 卸载挂载分区
    echo -e "${INFO}▶ 卸载 ${dev} ..."
    execute "umount ${dev}"
    sleep 1

    # 9. 删除创建的目录
    rm -rvf ${sd_mount_dir}
    echo -e "✅ 烧写${img} 到 ${dev} 完成！"
    cdo
}

# 关闭ext4分区的journal日志功能,否则从sd卡挂载根文件系统会失败
# ubuntu内核版本：5.15.0-122-generic
# nxp 内核版本：4.19.71
function sd_remove_ext4_journal()
{
    local dev=${SD_PART[1]}
    echo -e "${INFO}▶ 要处理的是根文件系统分区 ${PINK}${dev}${CLS} ..."
    # 查看分区特性
    tune2fs -l ${dev} | grep feature
    # 卸载分区
    umount ${dev} 2>/dev/null
    # 修改分区日志
    tune2fs -O ^has_journal ${dev}
    # 确认分区特性
    tune2fs -l ${dev} | grep feature
    echo -e "✅ ${dev} 分区journal日志处理完毕。"
}
# 格式化sd卡
function sd_format()
{
    sd_start1M_clean
    sd_partition
    sd_partition_mkfs
}

# 制作启动盘
function sd_boot_make()
{
    download_uboot2sd
    download_kernel_dtb2sd
    download_rootfs2sd
    sd_remove_ext4_journal
}

function echo_menu()
{
    sd_get_device  # 最开始要先获取sd卡信息
    sd_umount      # 然后卸载所有分区
    echo "================================================="
	echo -e "${GREEN}               build project ${CLS}"
	echo -e "${GREEN}                by @苏木    ${CLS}"
	echo "================================================="
    echo -e "${PINK}current path         :$(pwd)${CLS}"
    echo -e "${PINK}SCRIPT_CURRENT_PATH  :${SCRIPT_CURRENT_PATH}${CLS}"
    echo ""
    echo -e "*${GREEN} [0] sd卡启动盘制作(不格式化)${CLS}"
    echo -e "* [1] sd卡格式化"
    echo -e "* [2] 烧写uboot到sd卡"
    echo -e "* [2] 烧写内核和设备树到sd卡分区1"
    echo -e "* [4] 烧写根文件系统到sd卡分区2"
    echo -e "* [5] 移除ext4分区的has_journal特性"
    echo -e "* [6] 格式化后制作启动盘(一步到位)"
    echo "================================================="
}

function func_process()
{
	read -p "请选择功能,默认选择0:" choose
	case "${choose}" in
		"0")sd_boot_make;;
		"1")sd_format;;
		"2")download_uboot2sd;;
        "3")download_kernel_dtb2sd;;
        "4")download_rootfs2sd;;
        "5")sd_remove_ext4_journal;;
        "6") 
            sd_format
            sd_boot_make
            ;;
		*)sd_boot_make;;
	esac
}
# 检查是否是sudo执行
if [[ $EUID -ne 0 ]]; then
    echo -e "⚠️  请使用 sudo ./${SCRIPT_NAME} 运行脚本"
    exit 1
fi
echo_menu
func_process
