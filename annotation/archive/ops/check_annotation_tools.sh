#!/bin/bash

# 检查T01/T02注释所需的工具

set -e

PROJECT_DIR="/path/to/project_root"
LOG_FILE="${PROJECT_DIR}/logs/tool_check_$(date +%Y%m%d).log"

mkdir -p "${PROJECT_DIR}/logs"

echo "=== 检查注释工具 ===" | tee "$LOG_FILE"

# 工具列表
declare -A tools
tools["fastp"]="转录组质控"
tools["hisat2"]="转录组比对"
tools["stringtie"]="转录本组装"
tools["samtools"]="BAM文件处理"
tools["RepeatModeler"]="重复序列预测"
tools["RepeatMasker"]="重复序列注释"
tools["augustus"]="基因预测"
tools["genemark"]="基因预测"
tools["snap"]="基因预测"
tools["GeMoMa"]="同源预测"
tools["PASA"]="转录组证据整合"
tools["EVM"]="证据整合"
tools["diamond"]="功能注释"
tools["interproscan"]="功能注释"
tools["emapper.py"]="eggNOG-mapper"

missing_tools=()
installed_tools=()

for tool in "${!tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "✓ $tool (${tools[$tool]}): $(which $tool)" | tee -a "$LOG_FILE"
        installed_tools+=("$tool")
    else
        echo "✗ $tool (${tools[$tool]}): 未安装" | tee -a "$LOG_FILE"
        missing_tools+=("$tool")
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "=== 工具检查总结 ===" | tee -a "$LOG_FILE"
echo "已安装: ${#installed_tools[@]} 个工具" | tee -a "$LOG_FILE"
echo "缺失: ${#missing_tools[@]} 个工具" | tee -a "$LOG_FILE"

if [ ${#missing_tools[@]} -gt 0 ]; then
    echo "" | tee -a "$LOG_FILE"
    echo "缺失的工具:" | tee -a "$LOG_FILE"
    for tool in "${missing_tools[@]}"; do
        echo "  - $tool: ${tools[$tool]}" | tee -a "$LOG_FILE"
    done
    echo "" | tee -a "$LOG_FILE"
    echo "建议安装命令:" | tee -a "$LOG_FILE"
    echo "conda install -c bioconda fastp hisat2 stringtie samtools repeatmasker augustus genemark gmes genemark-es snap gemoma pasa evidencemodeler diamond interproscan" | tee -a "$LOG_FILE"
fi

