#!/bin/bash

# 获取 script 目录
script_dir=$(readlink -f "$(dirname "$0")")

# 显示帮助信息
show_help() {
    echo "Usage: $0 --bam <bam_file_or_dir> --out <output_dir> [--batch <num_threads>]"
    echo "\nOptions:"
    echo "  --bam, -b        Path to BAM file or directory (if batch mode)"
    echo "  --out, -o        Output directory"
    echo "  --batch, -t      Enable batch processing with the given number of threads (default: 1)"
    echo "  --help, -h       Show this help message"
    exit 0
}

# 参数解析
batch_mode=false
batch_size=1  # 默认 batch_size=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --bam|-b)
            bam_path="$2"
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

echo "[DEBUG] BAM path: $bam_path"
echo "[DEBUG] Output path: $out_path"
echo "[DEBUG] Batch mode: $batch_mode (Threads: $batch_size)"

# 参数检查
if [[ -z "$bam_path" || -z "$out_path" ]]; then
    echo "Error: Missing required parameters."
    show_help
fi

mkdir -p "$out_path"

# 检查输入文件/目录是否存在
if [[ "$batch_mode" == true ]]; then
    if [[ ! -d "$bam_path" ]]; then
        echo "Error: Batch mode requires a directory for --bam."
        exit 1
    fi
    bam_files=$(find "$bam_path" -type f -name "*.bam")
    echo "[DEBUG] Found BAM files: $bam_files"
else
    bam_files="$bam_path"
    echo "[DEBUG] Processing single BAM file: $bam_files"
fi

if [[ -z "$bam_files" ]]; then
    echo "Error: No BAM files found."
    exit 1
fi

# 逐个处理 BAM 文件
for bam_file in $bam_files; do
    prefix=$(basename "$bam_file" .bam)
    docker run --rm \
        -v "$bam_file:/data.bam" \
        -v "$out_path:/out" \
        dazauzi/picard-cram \
        java -jar /opt/picard/picard.jar MarkDuplicates \
        I=/data.bam \
        O=/out/${prefix}_marked.bam \
        M=/out/${prefix}_marked_dup_metrics.txt
    echo "Processed: $bam_file"
done

