#!/bin/bash

# RepeatMasker进度监控脚本

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/repeatmasker_run.log"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo "=========================================="
echo "RepeatMasker 进度监控"
echo "=========================================="
echo ""

# 检查进程
check_processes() {
    echo -e "${BLUE}【进程状态】${NC}"
    
    local main_pid=$(pgrep -f "RepeatMasker.*BH.Chr.final.fa" | head -1)
    local process_pid=$(pgrep -f "ProcessRepeats.*BH" | head -1)
    
    if [ -n "$main_pid" ]; then
        local etime=$(ps -o etime= -p "$main_pid" 2>/dev/null | tr -d ' ')
        local cpu=$(ps -o %cpu= -p "$main_pid" 2>/dev/null | tr -d ' ')
        local mem=$(ps -o %mem= -p "$main_pid" 2>/dev/null | tr -d ' ')
        echo -e "  ${GREEN}✓${NC} RepeatMasker主进程: PID $main_pid"
        echo -e "     运行时间: $etime | CPU: ${cpu}% | 内存: ${mem}%"
    else
        echo -e "  ${YELLOW}⚠${NC} RepeatMasker主进程: 未找到"
    fi
    
    if [ -n "$process_pid" ]; then
        local etime=$(ps -o etime= -p "$process_pid" 2>/dev/null | tr -d ' ')
        local cpu=$(ps -o %cpu= -p "$process_pid" 2>/dev/null | tr -d ' ')
        local mem=$(ps -o rss= -p "$process_pid" 2>/dev/null | awk '{printf "%.1f", $1/1024}')
        echo -e "  ${GREEN}✓${NC} ProcessRepeats子进程: PID $process_pid"
        echo -e "     运行时间: $etime | CPU: ${cpu}% | 内存: ${mem}MB"
    else
        echo -e "  ${YELLOW}⚠${NC} ProcessRepeats子进程: 未找到（可能已完成）"
    fi
    
    echo ""
}

# 检查BH输出文件
check_bh_output() {
    echo -e "${BLUE}【BH基因组处理状态】${NC}"
    
    local work_dir="${ANNOTATION_DIR}/BH/repeat/RM_1520083.FriDec191059142025"
    
    if [ -d "$work_dir" ]; then
        # 检查.out文件
        if [ -f "${work_dir}/BH.Chr.final.fa.out" ]; then
            local size=$(du -h "${work_dir}/BH.Chr.final.fa.out" | cut -f1)
            local mtime=$(stat -c %y "${work_dir}/BH.Chr.final.fa.out" | cut -d' ' -f2 | cut -d'.' -f1)
            echo -e "  ${GREEN}✓${NC} 注释报告: BH.Chr.final.fa.out ($size, 更新: $mtime)"
        fi
        
        # 检查.gff文件
        if [ -f "${work_dir}/BH.Chr.final.fa.out.gff" ]; then
            local size=$(du -h "${work_dir}/BH.Chr.final.fa.out.gff" | cut -f1)
            local mtime=$(stat -c %y "${work_dir}/BH.Chr.final.fa.out.gff" | cut -d' ' -f2 | cut -d'.' -f1)
            echo -e "  ${GREEN}✓${NC} GFF注释: BH.Chr.final.fa.out.gff ($size, 更新: $mtime)"
        fi
        
        # 检查.masked文件
        if [ -f "${work_dir}/BH.Chr.final.fa.masked" ]; then
            local size=$(du -h "${work_dir}/BH.Chr.final.fa.masked" | cut -f1)
            echo -e "  ${GREEN}✓${NC} 掩蔽基因组: BH.Chr.final.fa.masked ($size) - ${GREEN}已完成！${NC}"
        else
            echo -e "  ${YELLOW}⏳${NC} 掩蔽基因组: 生成中..."
        fi
        
        # 检查.cat.gz文件
        if [ -f "${work_dir}/BH.Chr.final.fa.cat.gz" ]; then
            local size=$(du -h "${work_dir}/BH.Chr.final.fa.cat.gz" | cut -f1)
            echo -e "  ${BLUE}ℹ${NC} 中间文件: BH.Chr.final.fa.cat.gz ($size)"
        fi
    else
        echo -e "  ${RED}✗${NC} 工作目录不存在"
    fi
    
    echo ""
}

# 检查CK状态
check_ck_status() {
    echo -e "${BLUE}【CK基因组处理状态】${NC}"
    
    local ck_pid=$(pgrep -f "RepeatMasker.*CK.Chr.final.fa" | head -1)
    
    if [ -n "$ck_pid" ]; then
        local etime=$(ps -o etime= -p "$ck_pid" 2>/dev/null | tr -d ' ')
        echo -e "  ${GREEN}✓${NC} CK处理已开始 (PID: $ck_pid, 运行时间: $etime)"
    else
        echo -e "  ${YELLOW}⏸️${NC} 等待BH完成后开始"
    fi
    
    echo ""
}

# 检查最新日志
check_log() {
    echo -e "${BLUE}【最新日志（最后5行）】${NC}"
    if [ -f "$LOG_FILE" ]; then
        tail -5 "$LOG_FILE" | sed 's/^/  /'
    else
        echo -e "  ${YELLOW}⚠${NC} 日志文件不存在"
    fi
    echo ""
}

# 主循环
while true; do
    clear
    echo "=========================================="
    echo "RepeatMasker 进度监控 - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    check_processes
    check_bh_output
    check_ck_status
    check_log
    
    echo "=========================================="
    echo "按 Ctrl+C 退出监控"
    echo "每30秒自动刷新..."
    echo ""
    
    sleep 30
done

