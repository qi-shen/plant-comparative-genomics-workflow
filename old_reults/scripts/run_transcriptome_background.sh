#!/bin/bash
# 后台运行转录组处理脚本

cd /path/to/project_root
source ~/miniconda3/etc/profile.d/conda.sh
conda activate base

nohup bash scripts/transcriptome_processing.sh > logs/transcriptome_background.log 2>&1 &

echo "转录组处理已在后台运行，PID: $!"
echo "查看进度: tail -f logs/transcriptome_background.log"
