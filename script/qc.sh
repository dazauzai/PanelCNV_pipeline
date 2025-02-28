#!/bin/bash

# 获取 script 目录
script_dir=$(readlink -f "$(dirname "$0")")

# 显示帮助信息
show_help() {
    echo "Usage: $0 --fastq <fastq_file_or_dir> --out <output_dir> [--batch] [--cpus <num>] [--memory <size>]"
    echo "\nOptions:"
    echo "  --fastq, -f      Path to FASTQ file or directory (if batch mode)"
    echo "  --out, -o        Output directory"
    echo "  --batch, -b      Enable batch processing"
    echo "  --cpus, -c       Set CPU limit for Docker container (default: 8)"
    echo "  --memory, -m     Set memory limit for Docker container (default: 8GB)"
    echo "  --help, -h       Show this help message"
    exit 0
}

# 参数解析
batch_mode=false
cpu_cores=8  # 默认 CPU 核心数 8
memory_size="8g"  # 默认内存 8GB

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fastq|-f)
            fastq_path="$2"
            shift 2
            ;;
        --out|-o)
            out_path="$2"
            shift 2
            ;;
        --batch|-b)
            batch_mode=true
            shift 1
            ;;
        --cpus|-c)
            cpu_cores="$2"
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

echo "[DEBUG] Pulling Docker image: biocontainers/fastqc:v0.11.9_cv8"
docker pull biocontainers/fastqc:v0.11.9_cv8

echo "[DEBUG] FASTQ path: $fastq_path"
echo "[DEBUG] Output path: $out_path"
echo "[DEBUG] Batch mode: $batch_mode"
echo "[DEBUG] CPU cores: $cpu_cores"
echo "[DEBUG] Memory size: $memory_size"

# 参数检查
if [[ -z "$fastq_path" || -z "$out_path" ]]; then
    echo "Error: Missing required parameters."
    show_help
fi
mkdir -p "$out_path"

# 检查输入文件/目录是否存在
if [[ "$batch_mode" == true ]]; then
    if [[ ! -d "$fastq_path" ]]; then
        echo "Error: Batch mode requires a directory for --fastq."
        exit 1
    fi
    fastq_files=$(find "$fastq_path" -type f -name "*.fastq.gz")
    echo "[DEBUG] Found FASTQ files: $fastq_files"
else
    fastq_files="$fastq_path"
    echo "[DEBUG] Processing single FASTQ file: $fastq_files"
fi
if [[ -z "$fastq_files" ]]; then
    echo "Error: No FASTQ files found."
    exit 1
fi

# 逐个处理 FASTQ 文件
for fastq_file in $fastq_files; do
    prefix=$(basename "$fastq_file")
    echo "[INFO] Running FastQC on $fastq_file"
    docker run --rm --cpus="$cpu_cores" --memory="$memory_size" \
        -v "$fastq_file:/data/$prefix" \
        -v "$out_path:/out" \
        biocontainers/fastqc:v0.11.9_cv8 \
        bash -c "fastqc -o /out /data/$prefix"
    echo "[INFO] Processed: $fastq_file"
done

