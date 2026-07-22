#!/bin/bash

# 准备BLAST数据库（SwissProt和Nr）

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/path/to/project_root"
DATABASE_DIR="${PROJECT_DIR}/databases"
LOG_FILE="${PROJECT_DIR}/logs/prepare_blast_databases_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$DATABASE_DIR" "${PROJECT_DIR}/logs"

# 激活conda base环境
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
    conda activate base
    export PATH="$HOME/miniconda3/bin:$PATH"
fi

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

# 检查网络连接
check_network() {
    log_info "检查网络连接..."
    
    if ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
        log_info "✅ 网络连接正常"
        return 0
    else
        log_error "❌ 网络连接失败，请检查网络设置"
        return 1
    fi
}

# 检查BLAST工具
check_blast() {
    if command -v makeblastdb &> /dev/null; then
        MAKEBLASTDB="makeblastdb"
    elif [ -f "/home/shenq/Biosofts/ncbi-blast-2.14.0+/bin/makeblastdb" ]; then
        MAKEBLASTDB="/home/shenq/Biosofts/ncbi-blast-2.14.0+/bin/makeblastdb"
    else
        log_error "makeblastdb未找到"
        return 1
    fi
    
    log_info "使用makeblastdb: $MAKEBLASTDB"
    "$MAKEBLASTDB" -version | tee -a "$LOG_FILE"
}

# 检查数据库是否存在
check_database() {
    local db_name=$1
    local db_path="${DATABASE_DIR}/${db_name}"
    
    if [ -f "${db_path}.phr" ] || [ -f "${db_path}.00.phr" ]; then
        return 0  # 数据库存在
    else
        return 1  # 数据库不存在
    fi
}

# 安全的下载函数（带断点续传和重试）
safe_download() {
    local url=$1
    local output_file=$2
    local max_retries=${3:-5}  # 默认重试5次
    local retry_delay=${4:-10}  # 默认等待10秒
    
    log_info "开始下载: $(basename $output_file)"
    log_info "URL: $url"
    
    local attempt=1
    while [ $attempt -le $max_retries ]; do
        log_info "下载尝试 $attempt/$max_retries"
        
        # 使用wget下载，支持断点续传
        if wget -c --timeout=60 --tries=3 --progress=bar:force \
           --user-agent="Mozilla/5.0" \
           -O "$output_file.tmp" "$url" >> "$LOG_FILE" 2>&1; then
            
            # 下载成功，移动文件
            mv "$output_file.tmp" "$output_file"
            
            # 验证文件完整性
            if [ -f "$output_file" ] && [ -s "$output_file" ]; then
                local file_size=$(du -h "$output_file" | cut -f1)
                log_info "✅ 下载成功: $output_file ($file_size)"
                return 0
            else
                log_error "下载的文件为空或损坏"
                rm -f "$output_file.tmp" "$output_file"
            fi
        else
            log_warn "下载失败 (尝试 $attempt/$max_retries)"
            rm -f "$output_file.tmp"
        fi
        
        if [ $attempt -lt $max_retries ]; then
            log_info "等待 $retry_delay 秒后重试..."
            sleep $retry_delay
            # 指数退避
            retry_delay=$((retry_delay * 2))
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "下载失败，已达到最大重试次数"
    return 1
}

# 下载SwissProt数据库
download_swissprot() {
    log_step "准备SwissProt数据库..."
    
    local db_name="swissprot"
    local db_path="${DATABASE_DIR}/${db_name}"
    
    if check_database "$db_name"; then
        log_info "✅ SwissProt数据库已存在: $db_path"
        return 0
    fi
    
    # 检查是否有未压缩的fasta文件
    if [ -f "${DATABASE_DIR}/uniprot_sprot.fasta" ]; then
        log_info "找到uniprot_sprot.fasta，创建数据库..."
        "$MAKEBLASTDB" -in "${DATABASE_DIR}/uniprot_sprot.fasta" \
                       -dbtype prot \
                       -out "$db_path" \
                       -title "SwissProt" \
                       >> "$LOG_FILE" 2>&1
        
        if check_database "$db_name"; then
            log_info "✅ SwissProt数据库创建成功"
            return 0
        fi
    elif [ -f "${DATABASE_DIR}/swissprot.fasta" ]; then
        log_info "找到swissprot.fasta，创建数据库..."
        "$MAKEBLASTDB" -in "${DATABASE_DIR}/swissprot.fasta" \
                       -dbtype prot \
                       -out "$db_path" \
                       -title "SwissProt" \
                       >> "$LOG_FILE" 2>&1
        
        if check_database "$db_name"; then
            log_info "✅ SwissProt数据库创建成功"
            return 0
        fi
    fi
    
    # 需要下载
    local fasta_file="${DATABASE_DIR}/uniprot_sprot.fasta"
    local gz_file="${fasta_file}.gz"
    
    # 检查是否有未完成的下载
    if [ -f "$gz_file" ] && [ -s "$gz_file" ]; then
        log_info "发现部分下载的文件，检查完整性..."
        # 尝试继续下载
        log_info "继续下载..."
    fi
    
    # 下载SwissProt数据库
    local swissprot_url="ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz"
    
    log_info "开始下载SwissProt数据库..."
    log_info "文件大小: 约200-300MB"
    
    if safe_download "$swissprot_url" "$gz_file" 5 10; then
        # 解压文件
        log_info "解压文件: $gz_file"
        if gunzip -f "$gz_file" >> "$LOG_FILE" 2>&1; then
            if [ -f "$fasta_file" ]; then
                log_info "✅ 解压成功"
                # 创建BLAST数据库
                log_info "创建BLAST数据库..."
                "$MAKEBLASTDB" -in "$fasta_file" \
                               -dbtype prot \
                               -out "$db_path" \
                               -title "SwissProt" \
                               >> "$LOG_FILE" 2>&1
                
                if check_database "$db_name"; then
                    log_info "✅ SwissProt数据库创建成功"
                    return 0
                else
                    log_error "SwissProt数据库创建失败"
                    return 1
                fi
            else
                log_error "解压后文件不存在"
                return 1
            fi
        else
            log_error "解压失败"
            return 1
        fi
    else
        log_error "SwissProt数据库下载失败"
        log_warn "可以手动下载："
        echo "  cd $DATABASE_DIR"
        echo "  wget -c $swissprot_url"
        echo "  gunzip uniprot_sprot.fasta.gz"
        echo "  makeblastdb -in uniprot_sprot.fasta -dbtype prot -out swissprot"
        return 1
    fi
}

# 使用update_blastdb.pl下载Nr数据库（推荐方法）
download_nr_with_update_blastdb() {
    log_info "使用update_blastdb.pl下载Nr数据库（推荐方法）..."
    
    # 检查update_blastdb.pl
    if command -v update_blastdb.pl &> /dev/null; then
        UPDATE_BLASTDB="update_blastdb.pl"
    elif [ -f "/home/shenq/Biosofts/ncbi-blast-2.14.0+/bin/update_blastdb.pl" ]; then
        UPDATE_BLASTDB="/home/shenq/Biosofts/ncbi-blast-2.14.0+/bin/update_blastdb.pl"
    else
        log_warn "update_blastdb.pl未找到，使用手动下载方法"
        return 1
    fi
    
    log_info "使用: $UPDATE_BLASTDB"
    
    cd "$DATABASE_DIR"
    
    local max_retries=3
    local attempt=1
    
    while [ $attempt -le $max_retries ]; do
        log_info "下载尝试 $attempt/$max_retries"
        
        if "$UPDATE_BLASTDB" --decompress --force nr >> "$LOG_FILE" 2>&1; then
            if check_database "nr"; then
                log_info "✅ Nr数据库下载成功"
                return 0
            fi
        else
            log_warn "下载失败 (尝试 $attempt/$max_retries)"
            if [ $attempt -lt $max_retries ]; then
                log_info "等待30秒后重试..."
                sleep 30
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "update_blastdb.pl下载失败"
    return 1
}

# 准备Nr数据库
prepare_nr() {
    log_step "准备Nr数据库..."
    
    local db_name="nr"
    local db_path="${DATABASE_DIR}/${db_name}"
    
    if check_database "$db_name"; then
        log_info "✅ Nr数据库已存在: $db_path"
        return 0
    fi
    
    log_info "Nr数据库不存在"
    log_warn "Nr数据库较大（~100GB），下载可能需要很长时间"
    
    # 方法1: 使用update_blastdb.pl（推荐）
    if download_nr_with_update_blastdb; then
        return 0
    fi
    
    # 方法2: 检查是否有nr.fasta文件
    if [ -f "${DATABASE_DIR}/nr.fasta" ]; then
        log_info "找到nr.fasta，创建数据库（这可能需要很长时间）..."
        log_warn "Nr数据库创建可能需要数小时..."
        "$MAKEBLASTDB" -in "${DATABASE_DIR}/nr.fasta" \
                       -dbtype prot \
                       -out "$db_path" \
                       -title "Nr" \
                       >> "$LOG_FILE" 2>&1
        
        if check_database "$db_name"; then
            log_info "✅ Nr数据库创建成功"
            return 0
        else
            log_error "Nr数据库创建失败"
            return 1
        fi
    fi
    
    # 方法3: 手动下载提示
    log_warn "需要手动准备Nr数据库"
    log_info "推荐方法1（使用update_blastdb.pl）："
    echo "  cd $DATABASE_DIR"
    echo "  update_blastdb.pl --decompress --force nr"
    echo ""
    log_info "或方法2（手动下载tar.gz文件）："
    echo "  cd $DATABASE_DIR"
    echo "  # 下载所有nr.*.tar.gz文件（约100GB）"
    echo "  for i in {00..99}; do"
    echo "    wget -c ftp://ftp.ncbi.nlm.nih.gov/blast/db/nr.\${i}.tar.gz"
    echo "  done"
    echo "  # 解压所有文件"
    echo "  for file in nr.*.tar.gz; do tar -xzf \$file; done"
    echo ""
    
    return 1
}

# 主函数
main() {
    log_info "=========================================="
    log_info "准备BLAST数据库"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    check_blast
    
    # 检查网络连接
    if ! check_network; then
        log_error "网络连接失败，无法下载数据库"
        log_warn "请检查网络后重新运行"
        exit 1
    fi
    
    echo ""
    
    # 准备SwissProt
    download_swissprot
    
    echo ""
    
    # 准备Nr
    prepare_nr
    
    log_info ""
    log_info "=========================================="
    log_info "数据库准备检查完成"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    # 显示数据库状态
    log_info ""
    log_info "【数据库状态】"
    if check_database "swissprot"; then
        log_info "  ✅ SwissProt: ${DATABASE_DIR}/swissprot"
    else
        log_warn "  ❌ SwissProt: 未准备"
    fi
    
    if check_database "nr"; then
        log_info "  ✅ Nr: ${DATABASE_DIR}/nr"
    else
        log_warn "  ❌ Nr: 未准备"
    fi
}

main "$@"
