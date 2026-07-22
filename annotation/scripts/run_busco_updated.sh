#!/bin/bash
# 对PASA更新后的蛋白质序列运行BUSCO评估

BUSCO_BASE_DIR="${PROJECT_ROOT}/annotation/evaluation/busco_updated"
LOG_DIR="${PROJECT_ROOT}/logs"
LINEAGE_PATH="${PROJECT_ROOT}/busco_downloads/lineages/embryophyta_odb10"
THREADS=32

mkdir -p "$BUSCO_BASE_DIR"
mkdir -p "$LOG_DIR"

declare -A species_peps
species_peps[T01]="${PROJECT_ROOT}/annotation/T01/pasa_update/BH_pasa_updated_filtered.pep.fa"
species_peps[T02]="${PROJECT_ROOT}/annotation/T02/pasa_update/CK_pasa_updated_filtered.pep.fa"

run_busco() {
    local pep_file=$1
    local species_name=$2
    local output_dir="${BUSCO_BASE_DIR}/${species_name}"
    local log_file="${LOG_DIR}/busco_updated_${species_name}_$(date +%Y%m%d_%H%M%S).log"

    if [ ! -f "$pep_file" ]; then
        echo "错误: 蛋白质文件不存在: $pep_file"
        return 1
    fi

    echo "运行BUSCO评估: $species_name (更新后)"
    echo "蛋白质文件: $pep_file"
    echo "输出目录: $output_dir"

    mkdir -p "$output_dir"

    conda run -n busco busco \
        -i "$pep_file" \
        -l "$LINEAGE_PATH" \
        -o "${species_name}" \
        -m proteins \
        -c "$THREADS" \
        --offline \
        -f \
        --out_path "$output_dir" \
        2>&1 | tee "$log_file" &
    
    echo $! > "${output_dir}/busco_pid.txt"
    echo "  ${species_name} 任务已启动 (PID: $!)"
}

# 运行所有样本
for species in "${!species_peps[@]}"; do
    pep_file="${species_peps[$species]}"
    if [ -f "$pep_file" ]; then
        run_busco "$pep_file" "$species"
    else
        echo "跳过 ${species} (文件不存在: $pep_file)"
    fi
done

echo "等待所有BUSCO评估完成..."
for species in "${!species_peps[@]}"; do
    pid_file="${BUSCO_BASE_DIR}/${species}/busco_pid.txt"
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        echo "等待 ${species} 任务完成 (PID: ${pid})..."
        wait "$pid"
        if [ $? -eq 0 ]; then
            echo "  ✓ ${species} 任务完成"
        else
            echo "  ✗ ${species} 任务失败"
        fi
    fi
done

echo "所有BUSCO评估完成！"
