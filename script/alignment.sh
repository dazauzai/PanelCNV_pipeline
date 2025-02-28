#!/bin/bash

# 获取 script 目录
script_dir=$(readlink -f "$(dirname "$0")")

# 显示帮助信息
show_help() {
    echo "Usage: $0 --fastq1 <fastq_R1> --fastq2 <fastq_R2> --reference <reference_fasta> --out <output_dir> [--batch] [--cpus <num>] [--memory <size>]"
    echo "\nOptions:"
    echo "  --fastq1, -1      Path to R1 FASTQ file"
    echo "  --fastq2, -2      Path to R2 FASTQ file"
    echo "  --fastq_dir, -f   Path to FASTQ directory (batch mode)"
    echo "  --reference, -r   Path to reference FASTA file"
    echo "  --out, -o         Output directory"
    echo "  --batch, -t       Enable batch processing"
    echo "  --cpus, -c        Number of CPUs to allocate (default: 8)"
    echo "  --memory, -m      Memory allocation for container (default: 1GB)"
    echo "  --help, -h        Show this help message"
    exit 0
}

# 解析参数
batch_mode=false
cpus=8
memory_size="16g"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fastq1|-1)
            fastq_path1="$2"
            shift 2
            ;;
        --fastq2|-2)
            fastq_path2="$2"
            shift 2
            ;;
        --fastq_dir|-f)
            fastq_dir="$2"
            batch_mode=true
            shift 2
            ;;
        --reference|-r)
            ref_path="$2"
            shift 2
            ;;
        --out|-o)
            out_path="$2"
            shift 2
            ;;
        --batch|-t)
            batch_mode=true
            shift 1
            ;;
        --cpus|-c)
            cpus="$2"
            shift 2
            ;;
        --memory|-m)
            memory_size="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo "Error: Unknown parameter $1"
            show_help
            ;;
    esac
done

# 检查必须的参数
if [[ -z "$ref_path" || -z "$out_path" ]]; then
    echo "Error: Missing required parameters."
    show_help
fi

# 确保输出目录存在
mkdir -p "$out_path"

echo "[DEBUG] Pulling Docker image: dukegcb/bwa-samtools"
docker pull dukegcb/bwa-samtools

echo "[DEBUG] Reference path: $ref_path"
echo "[DEBUG] Output path: $out_path"
echo "[DEBUG] Batch mode: $batch_mode"
echo "[DEBUG] CPU cores: $cpus"
echo "[DEBUG] Memory size: $memory_size"

# ================================
# **1. 确保 BWA & GATK 索引文件存在**
# ================================
ref_dir=$(dirname "$ref_path")  # 参考基因组所在目录
ref_base=$(basename "$ref_path")  # 参考基因组文件名（不含路径）

bwa_index_files=(
    "${ref_path}.amb"
    "${ref_path}.ann"
    "${ref_path}.bwt"
    "${ref_path}.pac"
    "${ref_path}.sa"
)

gatk_index_files=(
    "${ref_path}.fai"
    "${ref_path%.fasta}.dict"
)

missing_indexes=()

# 检查 BWA 和 GATK 索引
for file in "${bwa_index_files[@]}" "${gatk_index_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_indexes+=("$file")
    fi
done

# 如果有缺失的索引文件，则创建索引
if [[ ${#missing_indexes[@]} -gt 0 ]]; then
    echo "[INFO] Missing index files detected. Generating..."

    # **创建 BWA 索引**
    if [[ ! -f "${ref_path}.bwt" ]]; then
        echo "[INFO] Running BWA index..."
        docker run --rm -v "$ref_dir:/ref" dukegcb/bwa-samtools \
            bwa index /ref/"$ref_base"
    fi

    # **创建 SAMtools FASTA 索引**
    if [[ ! -f "${ref_path}.fai" ]]; then
        echo "[INFO] Running SAMtools faidx..."
        docker run --rm -v "$ref_dir:/ref" dukegcb/bwa-samtools \
            samtools faidx /ref/"$ref_base"
    fi

    # **创建 GATK Sequence Dictionary**
    if [[ ! -f "${ref_path%.fasta}.dict" ]]; then
        echo "[INFO] Running GATK CreateSequenceDictionary..."
        docker run --rm -v "$ref_dir:/ref" broadinstitute/gatk \
            gatk CreateSequenceDictionary -R /ref/"$ref_base" -O /ref/"$(basename "${ref_path%.fasta}.dict")"
    fi

    echo "[INFO] Index files successfully generated."
fi

# ================================
# **2. 处理 FASTQ 文件**
# ================================
if [[ "$batch_mode" == true ]]; then
    if [[ ! -d "$fastq_dir" ]]; then
        echo "Error: Batch mode requires a directory for --fastq_dir."
        exit 1
    fi
    fastq_files=$(find "$fastq_dir" -type f -name "*_R1_*.fastq.gz")
    echo "[DEBUG] Found FASTQ files: $fastq_files"
else
    fastq_files=("$fastq_path1")
fi

if [[ -z "$fastq_files" ]]; then
    echo "Error: No FASTQ files found."
    exit 1
fi

# ================================
# **3. 遍历并执行比对**
# ================================
for r1_file in $fastq_files; do
    r2_file="${r1_file/_R1_/_R2_}"  # 自动匹配 R2
    if [[ ! -f "$r2_file" ]]; then
        echo "[WARNING] Paired R2 file not found for $r1_file. Skipping..."
        continue
    fi

    prefix=$(basename "$r1_file" _R1_001.fastq.gz)

echo "[INFO] Running BWA-MEM for $fastq_path1 & $fastq_path2"
    docker run --rm --cpus="$cpus" --memory="$memory_size" \
    	-v "$(dirname "$fastq_path1"):/data" \
    	-v "$(dirname "$ref_path"):/ref" \
    	-v "$out_path:/out" \
    	dukegcb/bwa-samtools \
    	bash -c "set -x && exec bwa mem -t $cpus /ref/$(basename "$ref_path") /data/$(basename "$fastq_path1") /data/$(basename "$fastq_path2") | \
    	samtools view -bS - | \
    	samtools sort -o /out/${prefix}_sorted.bam -"

echo "[INFO] Alignment completed for: $fastq_path1 & $fastq_path2"


done

