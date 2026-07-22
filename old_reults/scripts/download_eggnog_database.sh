#!/bin/bash

# eggNOG数据库下载脚本（可选，如果以后需要）

set -e

PROJECT_DIR="/path/to/project_root"
DATABASE_DIR="/home/shenq/Biosofts/eggnog-mapper/data"

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
}

log_info "eggNOG数据库下载脚本"
log_info "数据库目录: $DATABASE_DIR"
log_info ""
log_info "使用以下命令下载eggNOG数据库："
log_info ""
log_info "cd $DATABASE_DIR"
log_info "/home/shenq/Biosofts/eggnog-mapper/download_eggnog_data.py --data_dir $DATABASE_DIR"
log_info ""
log_warn "注意: 数据库文件较大（约20-30GB），下载可能需要很长时间"

