#!/bin/bash

# 安装BUSCO工具脚本

set -e

echo "=== 安装BUSCO工具 ==="

# 检查conda
if ! command -v conda &> /dev/null; then
    echo "错误: conda未安装"
    exit 1
fi

echo "使用conda安装BUSCO..."
conda install -y -c bioconda busco

echo "检查BUSCO安装..."
busco --version

echo "=== BUSCO安装完成 ==="

