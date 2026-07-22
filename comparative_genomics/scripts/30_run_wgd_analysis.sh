#!/bin/bash
# WGD全基因组复制分析 - Ks分布计算 (修正版)
# 日期: 2026-01-13
# 修正: 使用wgd dmd产生的临时目录中的safe_id文件

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/common.sh"
wf_init

set -e

WORKDIR="$BASE_DIR/comparative_genomics/04_wgd"

echo "=========================================="
echo "WGD全基因组复制分析 (修正版)"
echo "开始时间: $(date)"
echo "=========================================="

# 激活wgd环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate wgd
export PYTHONNOUSERSITE=1

mkdir -p "$WORKDIR/ks_distribution"

# 定义CDS文件路径
declare -A CDS_FILES=(
    ["T01"]="$BASE_DIR/new_anno/T01.final.cds.fa"
    ["T02"]="$BASE_DIR/new_anno/T02.final.cds.fa"
    ["C02"]="$BASE_DIR/old_reults/results/C02/cds.fa"
    ["C03"]="$BASE_DIR/old_reults/results/comp/C03/cds.fa"
    ["C01"]="$BASE_DIR/old_reults/results/C01/C01.cds.fa"
)

# 分析近缘类群5个物种
for sp in T02 C02 C03 C01; do
    echo ""
    echo "=========================================="
    echo "分析 $sp - $(date)"
    echo "=========================================="

    cds_file="${CDS_FILES[$sp]}"
    outdir="$WORKDIR/ks_distribution/$sp"

    mkdir -p "$outdir"
    cd "$outdir"

    if [ ! -f "$cds_file" ]; then
        echo "警告: CDS文件不存在 $cds_file"
        continue
    fi

    # 检查是否已有Ks结果
    if [ -f "ks_result/"*".ks.tsv" ] 2>/dev/null; then
        echo "已存在Ks结果，跳过"
        continue
    fi

    # 复制CDS文件到工作目录（添加物种前缀）
    cds_local="${sp}.cds.fa"
    if [ ! -f "$cds_local" ]; then
        awk -v sp="$sp" '/^>/{gsub(/^>/, ">" sp "_"); print; next} {print}' "$cds_file" > "$cds_local"
        echo "已复制CDS文件: $cds_local ($(grep -c '^>' $cds_local) 条序列)"
    fi

    # Step 1: 运行wgd dmd (全基因组比较)
    echo "Step 1: 运行 wgd dmd..."
    tmpdir_dmd=""
    if [ ! -d "tmpdir" ]; then
        wgd dmd "$cds_local" -o . -n 16 --tmpdir tmpdir 2>&1 || echo "wgd dmd 有警告，继续..."
        tmpdir_dmd=$(ls -d tmpdir/wgdtmp_* 2>/dev/null | head -1)
    else
        tmpdir_dmd=$(ls -d tmpdir/wgdtmp_* 2>/dev/null | head -1)
        echo "  已存在tmpdir: $tmpdir_dmd"
    fi

    # 查找MCL文件和safe_id映射
    if [ -z "$tmpdir_dmd" ]; then
        echo "错误: 找不到wgd dmd临时目录"
        continue
    fi

    mcl_file=$(ls "$tmpdir_dmd"/*.mcl 2>/dev/null | head -1)
    safe_id_file="$tmpdir_dmd/${sp}.cds.fa.original_safe_id"

    if [ -z "$mcl_file" ] || [ ! -f "$safe_id_file" ]; then
        echo "错误: 找不到MCL文件或safe_id映射"
        continue
    fi

    echo "  MCL文件: $mcl_file"
    echo "  Safe ID映射: $safe_id_file"

    # 创建使用safe_id的CDS文件
    cds_safe="${sp}.cds.safe_id.fa"
    if [ ! -f "$cds_safe" ]; then
        echo "  创建safe_id CDS文件..."
        python3 << EOF
id_map = {}
with open('$safe_id_file') as f:
    next(f)
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) == 2:
            id_map[parts[0]] = parts[1]

with open('$cds_local') as fin, open('$cds_safe', 'w') as fout:
    for line in fin:
        if line.startswith('>'):
            orig_id = line[1:].strip()
            if orig_id in id_map:
                fout.write('>' + id_map[orig_id] + '\n')
            else:
                fout.write(line)
        else:
            fout.write(line)
print(f"转换完成: {len(id_map)} 个ID")
EOF
    fi

    # Step 2: 运行wgd ksd (Ks计算)
    echo "Step 2: 运行 wgd ksd..."
    rm -rf ks_result wgdtmp_*
    wgd ksd "$mcl_file" "$cds_safe" -o ks_result -n 16 2>&1 || echo "wgd ksd 有警告，继续..."

    # 检查结果
    if [ -f ks_result/*.ks.tsv ]; then
        echo "完成! Ks结果: $(ls ks_result/*.ks.tsv)"
        valid_count=$(grep -v "NaN" ks_result/*.ks.tsv | wc -l)
        echo "有效Ks记录: $valid_count 条"
    else
        echo "警告: 未生成Ks结果"
    fi

    cd $BASE_DIR
done

echo ""
echo "=========================================="
echo "WGD分析完成"
echo "结束时间: $(date)"
echo "输出目录: $WORKDIR/ks_distribution"
echo "=========================================="
