#!/bin/bash

# 获取 script 目录
script_dir=$(readlink -f "$(dirname "$0")")

# 显示帮助信息
show_help() {
    echo "Usage: $0 --cram <cram_file_or_dir> --reference <reference_fasta> --out <output_dir> [--batch <num_threads>]"
    echo "\nOptions:"
    echo "  --cram, -c       Path to CRAM file or directory (if batch mode)"
    echo "  --reference, -r  Path to reference FASTA file"
    echo "  --out, -o        Output directory"
    echo "  --batch, -t      Enable batch processing with the given number of threads"
    echo "  --help, -h       Show this help message"
    exit 0
}

# 参数解析
batch_mode=false
batch_size=1  # 默认 batch_size=1
memory_size="1g"  # 默认内存 1GB
cpu_cores="8"  # 默认 CPU 核心数 8

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cram|-c)
            cram_path="$2"
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
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                batch_size="$2"
                shift 2
            else
                batch_size=1  # 如果没有提供 batch_size，则默认 1
                shift 1
            fi
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

echo "[DEBUG] Pulling Docker image: dazauzi/picard-cram"
docker pull dazauzi/picard-cram

echo "[DEBUG] CRAM path: $cram_path"
echo "[DEBUG] Reference path: $ref_path"
echo "[DEBUG] Output path: $out_path"
echo "[DEBUG] Batch mode: $batch_mode (Threads: $batch_size)"

echo "[DEBUG] Checking required parameters..."
if [[ -z "$cram_path" || -z "$ref_path" || -z "$out_path" ]]; then
    echo "Error: Missing required parameters."
    show_help
fi
mkdir -p "$out_path"

# 检查输入文件/目录是否存在
if [[ "$batch_mode" == true ]]; then
    if [[ ! -d "$cram_path" ]]; then
        echo "Error: Batch mode requires a directory for --cram."
        exit 1
    fi
    cram_files=$(find "$cram_path" -type f -name "*.cram")
    num_files=$(echo "$cram_files" | wc -l)
    memory_size="$((num_files * 1))g"
    echo "[DEBUG] Found CRAM files: $cram_files (Total: $num_files)"
    echo "[DEBUG] Assigned memory: $memory_size"
else
    cram_files="$cram_path"
    memory_size="1g"
    echo "[DEBUG] Processing single CRAM file: $cram_files"
fi
if [[ -z "$cram_files" ]]; then
    echo "Error: No CRAM files found."
    exit 1
fi

# 逐个处理 CRAM 文件
for cram_file in $cram_files; do
    prefix=$(basename "$cram_file" .cram)
    docker run --rm --memory="$memory_size" --cpus="$cpu_cores" \
        -v "$cram_file:/data.cram" \
        -v "$ref_path:/ref.fasta" \
        -v "${ref_path}.fai:/ref.fasta.fai" \
        -v "$out_path:/out" \
        dazauzi/picard-cram \
        java -jar /opt/picard/picard.jar SamToFastq \
        I=/data.cram \
        FASTQ=/out/${prefix}_R1.fastq.gz \
        SECOND_END_FASTQ=/out/${prefix}_R2.fastq.gz \
        REFERENCE_SEQUENCE=/ref.fasta
    echo "[INFO] Processed: $cram_file"
done

