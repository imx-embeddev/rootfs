#!/bin/bash

# 下载并解压脚本（非交互版）
DOWNLOAD_DIR="./"
TEMP_LOG="/tmp/download_extract.log"

# 显示使用颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # 恢复默认颜色

# 错误处理函数
handle_error() {
    echo -e "${RED}错误发生在第 $1 行，退出状态码 $2${NC}"
    echo -e "详细日志见：$TEMP_LOG"
    exit 1
}

trap 'handle_error $LINENO $?' ERR

# 验证参数
if [ $# -ne 1 ] || [[ ! $1 =~ ^(http|https|ftp):// ]]; then
    echo -e "${RED}用法: $0 <下载URL>"
    echo -e "示例: $0 https://example.com/file.tar.gz${NC}"
    exit 1
fi

DOWNLOAD_URL=$1
FILENAME=$(basename "$DOWNLOAD_URL")
FILEPATH="$DOWNLOAD_DIR/$FILENAME"

# 下载文件
echo -e "${GREEN}▶ 开始下载文件 [$FILENAME] ...${NC}"
wget -cq --show-progress -O "$FILEPATH" "$DOWNLOAD_URL" 2>&1 | tee "$TEMP_LOG"

# 验证下载完整性
if [ ! -s "$FILEPATH" ]; then
    echo -e "${RED}文件下载失败${NC}"
    exit 1
fi

# 解压处理
echo ""
echo -e "${GREEN}✔ 下载完成，开始解压...${NC}"
case "$FILENAME" in
    *.tar.gz|*.tgz)    tar -xzf  "$FILEPATH" -C "$DOWNLOAD_DIR" ;;
    *.tar.bz2|*.tbz2)  tar -xjf  "$FILEPATH" -C "$DOWNLOAD_DIR" ;;
    *.tar.xz|*.txz)    tar -xJf  "$FILEPATH" -C "$DOWNLOAD_DIR" ;;
    *.zip)             unzip -qo "$FILEPATH" -d "$DOWNLOAD_DIR" ;;
    *.rar)             unrar x   "$FILEPATH" "$DOWNLOAD_DIR" >/dev/null ;;
    *.7z)              7z x      "$FILEPATH" -o"$DOWNLOAD_DIR" >/dev/null ;;
    *)
        echo -e "${RED}不支持的文件格式 [$FILENAME]"
        echo "支持类型：tar.gz/tgz, tar.bz2/tbz2, tar.xz/txz, zip, rar, 7z"
        exit 1
        ;;
esac

# 自动清理压缩包
rm -f "$FILEPATH"
echo -e "${GREEN}✔ 解压完成，压缩包已清理${NC}"

# 清理日志
rm -f "$TEMP_LOG"
