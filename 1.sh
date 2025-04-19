#!/bin/bash
# * =====================================================
# * Copyright © hk. 2022-2025. All rights reserved.
# * File name  : 1.sh
# * Author     : 苏木
# * Date       : 2025-04-19
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
    echo -e "⚠️ ✅ 🚩 📁 🕣️"
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
# buildroot相关
# ========================================================
BUILDROOT_VER=buildroot-2023.05.1
BUILDROOT_PRJ_ROOT=${PROJECT_ROOT}/${BUILDROOT_VER} # Buildroot源码目录
RESULT_OUTPUT=${BUILDROOT_PRJ_ROOT}/output/images

BOARD_NAME=alpha # nxp 表示编译nxp官方原版配置文件，alpha表示编译我们自定义的配置文件
BOARD_DEFCONFIG=imx6ullalpha_local_defconfig # 这里将会有两种因为主要是

ARCH_NAME=arm 
CROSS_COMPILE_NAME=arm-linux-gnueabihf-

COMPILE_PLATFORM=local # local：非githubaction自动打包，githubaction：githubaction自动打包
COMPILE_MODE=0         # 0,清除工程后编译，1,不清理直接编译
DOWNLOAD_SDCARD=0      # 0,不执行下载到sd卡的流程，1,编译完执行下载到sd卡流程
REDIRECT_LOG_FILE=
COMMAND_EXIT_CODE=0    # 要有一个初始值，不然可能会报错
V=0                    # 主要是保存到日志文件的时候可以改成1，这样可以看到更加详细的日志

# 脚本参数传入处理
# ========================================================
function usage()
{
	echo -e "================================================="
    echo -e "${PINK}./1.sh       : 根据菜单编译工程${CLS}"
    echo -e "${PINK}./1.sh -d    : 编译后下载到sd卡${CLS}"
    echo -e "${PINK}./1.sh -p 1  : githubaction自动编译工程${CLS}"
    echo -e "${PINK}./1.sh -m 1  : 增量编译，不清理工程，不重新配置${CLS}"
    echo -e ""
    echo -e "================================================="
}
# 脚本运行参数处理
echo -e "${CYAN}There are $# parameters: $@ (\$1~\$$#)${CLS}"
while getopts "b:p:m:" arg #选项后面的冒号表示该选项需要参数
    do
        case ${arg} in
            b)
                if [ $OPTARG == "nxp" ];then
                    BOARD_NAME=NXP
                fi
                ;;
            p)
                # echo "a's arg:$OPTARG"     # 参数存在$OPTARG中
                if [ $OPTARG == "1" ];then
                    COMPILE_PLATFORM=githubaction
                    BOARD_DEFCONFIG=imx6ullalpha_githubaction_defconfig  
                    REDIRECT_LOG_FILE="${RESULT_OUTPUT}/rootfs-make-$(date +%Y%m%d_%H%M%S).log"
                    V=0 # 保存详细日志就这里改成1 
                fi
                ;;
            m)
                if [ $OPTARG == "1" ];then
                    COMPILE_MODE=1
                fi
                ;;
            ?)  #当有不认识的选项的时候arg为?
                echo -e "${ERROR}unkonw argument..."
                exit 1
                ;;
        esac
    done

# 功能实现
# ========================================================
# 不知道为什么当日志和脚本在同一个目录，日志最后就会被删除
function log_redirect_start()
{
    # 启用日志时重定向输出
    if [[ -n "${REDIRECT_LOG_FILE}" ]]; then
        exec 3>&1 4>&2 # 备份原始输出描述符
        echo -e "${BLUE}▶ 编译日志保存到: 📁 ${REDIRECT_LOG_FILE}${CLS}"
        # 初始化日志目录
        if [ ! -d "$RESULT_OUTPUT" ];then
            mkdir -pv "$RESULT_OUTPUT"
        fi
        if [ -s "${REDIRECT_LOG_FILE}" ]; then
            exec >> "${REDIRECT_LOG_FILE}" 2>&1
        else
            exec > "${REDIRECT_LOG_FILE}" 2>&1
        fi
        
        # 日志头存放信息s
        echo -e "=== 开始执行命令 ==="
        echo -e "当前时间: $(date +'%Y-%m-%d %H:%M:%S')"
    fi
}

function log_redirect_recovery()
{
    # 恢复原始输出
    if [[ -n "${REDIRECT_LOG_FILE}" ]]; then
        echo -e "当前时间: $(date +'%Y-%m-%d %H:%M:%S')"
        echo -e "=== 执行命令结束 ==="
        exec 1>&3 2>&4

        # 输出结果
        if [ $1 -eq 0 ]; then
            echo -e "${GREEN}✅ 命令执行成功!${CLS}"
        else
            echo -e "${RED}命令执行成失败 (退出码: $1)${CLS}"
            [[ -n "${REDIRECT_LOG_FILE}" ]] && echo -e "${YELLOW}查看日志: tail -f ${REDIRECT_LOG_FILE}${CLS}"
        fi
        exec 3>&- 4>&- # 关闭备份描述符

        # 验证日志完整性
        if [[ -n "${REDIRECT_LOG_FILE}" ]]; then
            if [[ ! -s "${REDIRECT_LOG_FILE}" ]]; then
                echo -e "${YELLOW}⚠ 警告: 日志文件为空，可能未捕获到输出${CLS}"
            else
                echo -e "${BLUE}📁 日志大小: $(du -h "${REDIRECT_LOG_FILE}" | cut -f1)${CLS}"
            fi
        fi
    fi
}

# 获取buildroot源码
function get_buildroot_src()
{
    cd ${PROJECT_ROOT}
    # 由于下载完成后会直接解压，所以这里判断解压目录是否存在，若不存在才下载
    if [ -d "${BUILDROOT_VER}" ]; then
        return
    fi

    echo ""
    echo -e "🚩 ===> function ${FUNCNAME[0]}"
    echo -e "${PINK}current path :$(pwd)${CLS}"
    echo -e "${PINK}BOARD_DEFCONFIG :${BOARD_NAME} ${BOARD_DEFCONFIG}${CLS}"
    
    chmod 777 get_rootfs_src.sh
    source ./get_rootfs_src.sh https://buildroot.org/downloads/${BUILDROOT_VER}.tar.gz
}

# 编译buildroot，制作根文件系统
function buildroot_rootfs_build()
{
    cd ${PROJECT_ROOT}
    echo ""
    echo -e "🚩 ===> function ${FUNCNAME[0]}"
    echo -e "${PINK}current path    :$(pwd)${CLS}"
    echo -e "${PINK}BOARD_DEFCONFIG :${BOARD_NAME} ${BOARD_DEFCONFIG}${CLS}"

    get_start_time

    # 1. 拷贝默认配置文件，用于配置buildroot
    echo -e "${INFO}▶ 拷贝默认配置文件: copy rootfs_src_backup/${BUILDROOT_VER}/configs/*"
    cp -avf rootfs_src_backup/${BUILDROOT_VER}/configs/* ${BUILDROOT_PRJ_ROOT}/configs

    # 2. 拷贝dl目录下的一些工具源码，这是针对本地编译的时候可能有网络问题导致下载很慢
    if [ ${COMPILE_PLATFORM} != 'githubaction' ];then
        echo -e "${INFO}▶ 拷贝默认配置文件: copy rootfs_src_backup/${BUILDROOT_VER}/dl/*"
        cp -avf rootfs_src_backup/${BUILDROOT_VER}/dl ${BUILDROOT_PRJ_ROOT}
    fi

    # 3. 开始编译buildroot
    cd ${BUILDROOT_PRJ_ROOT}
    echo -e "${PINK}current path    :$(pwd)${CLS}"
    echo -e "${PINK}BOARD_DEFCONFIG :${BOARD_NAME} ${BOARD_DEFCONFIG}${CLS}"

    echo -e "${INFO}▶ 开始编译buildroot(githubaction编译大概需要4min)..."
    echo -e "${INFO}▶ make ${BOARD_DEFCONFIG}"
    echo -e "${INFO}▶ make"

    log_redirect_start
    make ${BOARD_DEFCONFIG} || COMMAND_EXIT_CODE=$?
    make || COMMAND_EXIT_CODE=$?
    log_redirect_recovery ${COMMAND_EXIT_CODE}
    get_end_time
    get_execute_time

    echo -e "${INFO}▶ 检查是否编译成功..."
    if [ ! -f "${RESULT_OUTPUT}/rootfs.tar" ];then
        echo -e "${RED}❌ ${RESULT_OUTPUT}/rootfs.tar 编译失败,请检查后重试!${CLS}"
    else
        echo -e "✅${RESULT_OUTPUT}/rootfs.tar 编译成功!"
    fi

    # # 3.修改busybox源码后重新编译
    # get_start_time
    # cd ${PROJECT_ROOT}
    # echo -e "${PINK}current path :$(pwd)${CLS}"
    # echo -e "${PINK}BOARD_DEFCONFIG :${BOARD_NAME} ${BOARD_DEFCONFIG}${CLS}"
    # echo -e "${INFO}▶ 正在拷贝buildroot中busybox相关配置文件..."
    # cp -avf rootfs_src_backup/${BUILDROOT_VER}/output/* ${BUILDROOT_PRJ_ROOT}/output
    
    # cd ${BUILDROOT_PRJ_ROOT}
    # echo -e "${PINK}current path :$(pwd)${CLS}"
    # echo -e "${PINK}BOARD_DEFCONFIG :${BOARD_NAME} ${BOARD_DEFCONFIG}${CLS}"

    # echo -e "${INFO}▶ 修改相关插件源码后重新开始编译buildroot(第二次编译会快一点)..."
    # # 下面这个命令相当于cp -f output/build/busybox-1.36.1/.config package/busybox/busybox.config
    # log_redirect_start
    # make busybox-update-config || COMMAND_EXIT_CODE=$?     # 更新 Buildroot 的 BusyBox 配置缓存,
    # make busybox-clean-for-rebuild || COMMAND_EXIT_CODE=$? # 这里不要好像也可以，但是为避免出现问题，还是清理一下
    # make busybox || COMMAND_EXIT_CODE=$?                   # 这里不要好像也可以，但是为避免出现问题，还是清理一下
    # make || COMMAND_EXIT_CODE=$?
    # log_redirect_recovery ${COMMAND_EXIT_CODE}
    # get_end_time
    # get_execute_time

    # echo -e "${INFO}▶ 检查是否编译成功..."
    # if [ ! -f "${RESULT_OUTPUT}/rootfs.tar" ];then
    #     echo -e "${RED}❌ ${RESULT_OUTPUT}/rootfs.tar 编译失败,请检查后重试!${CLS}"
    # else
    #     echo -e "✅${RESULT_OUTPUT}/rootfs.tar 编译成功!"
    # fi

}

# 编译完成后开始制作根文件系统
function buildroot_rootfs_make()
{
    cd ${PROJECT_ROOT}
    echo ""
    echo -e "🚩 ===> function ${FUNCNAME[0]}"
    echo -e "${PINK}current path    :$(pwd)${CLS}"
    echo -e "${PINK}BOARD_DEFCONFIG :${BOARD_NAME} ${BOARD_DEFCONFIG}${CLS}"

    echo -e "${INFO}▶ ${PROJECT_ROOT} 下有以下文件"
    ls -alh

    # 1. 进入buildroot源码目录的输出文件夹 buildroot-2023.05.1/output/images
    if [ ! -d "${RESULT_OUTPUT}" ];then
        echo -e ${ERROR}"${RESULT_OUTPUT} not exit!"
        return
    fi
    cd ${RESULT_OUTPUT}
    echo -e "${PINK}current path    :$(pwd)${CLS}"
    echo -e "${PINK}BOARD_DEFCONFIG :${BOARD_NAME} ${BOARD_DEFCONFIG}${CLS}"

    # 2. 检查根文件系统压缩包是否存在
    if [ ! -f "rootfs.tar" ];then
        echo -e ${ERROR}"rootfs.tar 不存在..."
        return
    fi
    echo -e "${INFO}▶ rootfs.tar 已生成..."
    echo -e "${INFO}▶ 清理之前的文件...rm -rvf rootfs-*.tar.bz2 imx6ull_rootfs"
    rm -rf rootfs-*.tar.bz2 imx6ull_rootfs

    # 3. 创建imx6ull_rootfs目录
    mkdir -pv imx6ull_rootfs
    tar xf rootfs.tar -C imx6ull_rootfs
    # ls imx6ull_rootfs -alh

    # 4. 完善根文件系统
    echo -e "${INFO}▶ 开始拷贝自定义根文件系统相关文件..."
    cp -avf ${PROJECT_ROOT}/rootfs_custom/* imx6ull_rootfs/

    # 5. 生成版本信息和输出文件名
    # 5.1 获取时间戳和git版本信息
    timestamp=$(LC_ALL=C date "+%b %d %Y %H:%M:%S %z") # # 生成时间戳（格式：年月日时分秒） $(date +%Y%m%d%H%M%S)
    #parent_dir=$(dirname "$(realpath "${PROJECT_ROOT}")") # 这个是获取的上一级目录的
    parent_dir=$(realpath "${PROJECT_ROOT}")
    # 判断是否是 Git 仓库并获取版本号
    if git -C "$parent_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        version=$(git -C "$parent_dir" rev-parse --short HEAD)
    else
        version="unknown"
    fi
    # 5.2 生成版本文件
    echo "Buildrootfs: buildroot-2023.05.1" > imx6ull_rootfs/version.txt
    echo "Build Time:${timestamp}" >> imx6ull_rootfs/version.txt
    echo "Build User:$USER" >> imx6ull_rootfs/version.txt
    echo "Git Commit:g${version}" >> imx6ull_rootfs/version.txt
    # 5.3 生成打包文件名
    formatted_time=$(date -d "${timestamp}" "+%Y%m%d%H%M%S") # 之前的时间格式存在空格，我这里还需要作为文件名，所以转换一下
    output_file="rootfs-${formatted_time}-${version}.tar.bz2"
    echo "rootfs-${formatted_time}-${version}" >> imx6ull_rootfs/version.txt
    
    # 6. 创建打包文件
    echo -e "${INFO}▶ 重新打包文件..."
    tar -jcf ${output_file} imx6ull_rootfs ${REDIRECT_LOG_FILE##*/}

    # 7. 验证压缩结果
    if [ -f "${output_file}" ]; then
        # echo "打包成功！文件结构验证："
        # tar -tjf "${output_file}"
        echo -e "${INFO}▶ 生成的压缩文件如下:"
        ls -lh "${output_file}"
    else
        echo ${ERROR}"文件打包失败!"
    fi
}

# 编译完成后开始制作根文件系统
function buildroot_rootfs_config_update()
{
    cd ${PROJECT_ROOT}
    echo ""
    echo -e "🚩 ===> function ${FUNCNAME[0]}"
    echo -e "${PINK}current path    :$(pwd)${CLS}"
    echo -e "${PINK}BOARD_DEFCONFIG :${BOARD_NAME} ${BOARD_DEFCONFIG}${CLS}"
    
    echo -e "${INFO}▶ 更新配置文件到源码备份目录..."
    cp -avf ${BUILDROOT_VER}/configs/imx6ullalpha*defconfig rootfs_src_backup/${BUILDROOT_VER}/configs
    cp -avf ${BUILDROOT_VER}/.config rootfs_src_backup/${BUILDROOT_VER}
}

function driver_modules_compile()
{
    cd ${PROJECT_ROOT}
    echo -e "🚩 ===> function ${FUNCNAME[0]}"
    echo -e "${PINK}current path    :$(pwd)${CLS}"
    echo -e "${PINK}BOARD_DEFCONFIG :${BOARD_NAME} ${BOARD_DEFCONFIG}${CLS}"

    # 1. clone 驱动仓库
    git clone --depth=1 https://gitee.com/sumumm/imx6ull-driver-demo
    if [ ! -d "imx6ull-driver-demo" ];then
        echo -e "${ERR}""imx6ull-driver-demo目录不存在!"
    fi

    # 2. 进入指定的驱动目录
    cd imx6ull-driver-demo/40_procfs_demo/02_driver_template
    echo -e "${PINK}current path         :$(pwd)"${CLS}
    make KERNELDIR="/home/runner/work/repo-linux-release/repo-linux-release/kernel_nxp_4.19.71"
    # make KERNELDIR="/home/sumu/7Linux/imx6ull-kernel"
    # 3. 打包成果物到对应目录
    cp -avf drivers_demo/*.ko ${PROJECT_ROOT}/rootfs_custom/firmware/modules
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
    echo -e "${PINK}BUILDROOT_PRJ_ROOT     :${BUILDROOT_PRJ_ROOT}${CLS}"
    echo -e "${PINK}BOARD_DEFCONFIG        :${BOARD_NAME} ${BOARD_DEFCONFIG}${CLS}"
    echo ""
    echo -e "* [0] githubaction制作根文件系统"
    echo -e "* [1] local制作根文件系统"
    echo -e "* [2] 本地打包根文件系统"
    echo -e "* [3] 更新配置文件到源码备份目录"
    echo "================================================="
}

function func_process()
{
    if [ ${COMPILE_PLATFORM} == 'githubaction' ];then
    choose=0
    else
    read -p "请选择功能,默认选择1:" choose
    fi
	case "${choose}" in
		"0")
            source_env_info
            get_buildroot_src
            buildroot_rootfs_build
            driver_modules_compile
            buildroot_rootfs_make
            ;;
        "1")
            get_buildroot_src
            buildroot_rootfs_build
            buildroot_rootfs_make
            ;;
        "2")
            buildroot_rootfs_make
            ;;
        "3")
            buildroot_rootfs_config_update
            ;;
		*) 
            get_buildroot_src
            buildroot_rootfs_build
            buildroot_rootfs_make
            ;;
	esac
}

echo_menu
func_process
