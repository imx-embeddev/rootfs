#!/bin/bash
# * =====================================================
# * Copyright © hk. 2022-2025. All rights reserved.
# * File name  : build.sh
# * Author     : 苏木
# * Date       : 2024-11-03
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

#===============================================
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
	echo "===*** 运行时间：$((end_seconds-start_seconds))s,time diff: ${duration} ***==="
}

function get_ubuntu_info()
{
    # 获取内核版本信息
    local kernel_version=$(uname -r) # -a选项会获得更详细的版本信息
    # 获取Ubuntu版本信息
    local ubuntu_version=$(lsb_release -ds)

    # 获取Ubuntu RAM大小
    local ubuntu_ram_total=$(cat /proc/meminfo |grep 'MemTotal' |awk -F : '{print $2}' |sed 's/^[ \t]*//g')
    # 获取Ubuntu 交换空间swap大小
    local ubuntu_swap_total=$(cat /proc/meminfo |grep 'SwapTotal' |awk -F : '{print $2}' |sed 's/^[ \t]*//g')
    #显示硬盘，以及大小
    #local ubuntu_disk=$(sudo fdisk -l |grep 'Disk' |awk -F , '{print $1}' | sed 's/Disk identifier.*//g' | sed '/^$/d')
    
    #cpu型号
    local ubuntu_cpu=$(grep 'model name' /proc/cpuinfo |uniq |awk -F : '{print $2}' |sed 's/^[ \t]*//g' |sed 's/ \+/ /g')
    #物理cpu个数
    local ubuntu_physical_id=$(grep 'physical id' /proc/cpuinfo |sort |uniq |wc -l)
    #物理cpu内核数
    local ubuntu_cpu_cores=$(grep 'cpu cores' /proc/cpuinfo |uniq |awk -F : '{print $2}' |sed 's/^[ \t]*//g')
    #逻辑cpu个数(线程数)
    local ubuntu_processor=$(grep 'processor' /proc/cpuinfo |sort |uniq |wc -l)
    #查看CPU当前运行模式是64位还是32位
    local ubuntu_cpu_mode=$(getconf LONG_BIT)

    # 打印结果
    echo "ubuntu: $ubuntu_version - $ubuntu_cpu_mode"
    echo "kernel: $kernel_version"
    echo "ram   : $ubuntu_ram_total"
    echo "swap  : $ubuntu_swap_total"
    echo "cpu   : $ubuntu_cpu,physical id is$ubuntu_physical_id,cores is $ubuntu_cpu_cores,processor is $ubuntu_processor"
}

# 本地虚拟机VMware开发环境信息
function dev_env_info()
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
#===============================================
# buildroot相关
buildroot_version=buildroot-2023.05.1
buildroot_project_path=./${buildroot_version}
buildroot_out_path=output/images
buildroot_rootfs_name=rootfs.tar

githubaction_ena=0 # 手动选择功能
DEF_CONFIG_TYPE=alpha # nxp 表示编译nxp官方原版配置文件，alpha表示编译我们自定义的配置文件
buildroot_board_cfg=imx6ullalpha_defconfig
# 脚本运行参数处理
echo "There are $# parameters: $@"
while getopts "g:t:" arg #选项后面的冒号表示该选项需要参数
    do
        case ${arg} in
            g)
                # echo "a's arg:$OPTARG"     # 参数存在$OPTARG中
                if [ $OPTARG == "1" ];then # 使用NXP官方的默认配置文件
                    githubaction_ena=1
                    buildroot_board_cfg=imx6ullalpha_githubaction_defconfig
                fi
                ;;
            t)
                # echo "a's arg:$OPTARG"     # 参数存在$OPTARG中
                if [ $OPTARG == "0" ];then # 使用NXP官方的默认配置文件
                    DEF_CONFIG_TYPE=nxp
                fi
                ;;
            ?)  #当有不认识的选项的时候arg为?
                echo "${ERR}unkonw argument..."
                exit 1
                ;;
        esac
    done

# Github Actions托管的linux服务器有以下用户级环境变量，系统级环境变量加上sudo好像也权限修改
# .bash_logout  当用户注销时，此文件将被读取，通常用于清理工作，如删除临时文件。
# .bashrc       此文件包含特定于 Bash Shell 的配置，如别名和函数。它在每次启动非登录 Shell 时被读取。
# .profile、.bash_profile 这两个文件位于用户的主目录下，用于设置特定用户的环境变量和启动程序。当用户登录时，
#                        根据 Shell 的类型和配置，这些文件中的一个或多个将被读取。
USER_ENV_FILE_BASHRC=~/.bashrc
USER_ENV_FILE_PROFILE=~/.profile
USER_ENV_FILE_BASHRC_PROFILE=~/.bash_profile
function source_env_info()
{
    if [ -f ${USER_ENV_FILE_PROFILE} ]; then
        source ${USER_ENV_FILE_BASHRC}
    fi
    # 修改可能出现的其他用户级环境变量，防止不生效
    if [ -f ${USER_ENV_FILE_PROFILE} ]; then
        source ${USER_ENV_FILE_PROFILE}
    fi

    if [ -f ${USER_ENV_FILE_BASHRC_PROFILE} ]; then
        source ${USER_ENV_FILE_BASHRC_PROFILE}
    fi

}

function githubaction_build_rootfs()
{
    cd ${SCRIPT_ABSOLUTE_PATH}
    cp -af rootfs/${buildroot_version}/configs/* ${buildroot_project_path}/configs
    cd ${buildroot_project_path}
    make ${buildroot_board_cfg}
    make 
}

function update_buildroot_rootfs()
{
    cd ${buildroot_project_path}/${buildroot_out_path}
    echo -e ${PINK}"current path:$(pwd)"${CLS}

    if [ ! -f "${buildroot_rootfs_name}" ];then
        echo -e "${ERR}${buildroot_rootfs_name}不存在..."
        return
    else
        tar -jcf ${buildroot_rootfs_name}.bz2 ${buildroot_rootfs_name}
        rm -rf ${buildroot_rootfs_name}
    fi
    mv ${buildroot_rootfs_name}.bz2 ${SCRIPT_ABSOLUTE_PATH}
}

function get_buildroot_src()
{
    chmod 777 get_rootfs_src.sh
    source ./get_rootfs_src.sh https://buildroot.org/downloads/${buildroot_version}.tar.gz
}

function echo_menu()
{
    echo "================================================="
	echo -e "${GREEN}               build project ${CLS}"
	echo -e "${GREEN}                by @苏木    ${CLS}"
	echo "================================================="
    echo -e "${PINK}current path           :$(pwd)${CLS}"
    echo -e "${PINK}SCRIPT_CURRENT_PATH    :${SCRIPT_CURRENT_PATH}${CLS}"
    echo -e "${PINK}ARCH_NAME              :${ARCH_NAME}${CLS}"
    echo -e "${PINK}CROSS_COMPILE_NAME     :${CROSS_COMPILE_NAME}${CLS}"
    echo -e "${PINK}buildroot_project_path :${buildroot_project_path}${CLS}"
    echo -e "${PINK}buildroot_board_cfg    :${buildroot_board_cfg}${CLS}"
    echo ""
    echo -e "* [0] 制作根文件系统"
    echo "================================================="
}

function func_process()
{
    if [ ${githubaction_ena} == '0' ];then
	read -p "请选择功能,默认选择0:" choose
    else
    source_env_info
    choose=0
    fi

	case "${choose}" in
		"0")
            get_buildroot_src
            githubaction_build_rootfs
            update_buildroot_rootfs
            ;;
		*) 
            get_buildroot_src
            githubaction_build_rootfs
            update_buildroot_rootfs
            ;;
	esac
}

echo_menu
func_process
