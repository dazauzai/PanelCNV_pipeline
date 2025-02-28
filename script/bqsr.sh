#!/bin/bash

# 获取 script 目录
script_dir=$(readlink -f "$(dirname "$0")")
temp_dir=$(mktemp -d)
echo "Temporary directory created: $temp_dir"

# 显示帮助信息
show_help() {
    echo "Usage: $0 --bam <bam_file_or_dir> --reference <reference_fasta> --vcf <known_sites_vcf> --out <output_dir> [--batch] [--memory <size>] [--cpus <num>]"
    echo "\nOptions:"
    echo "  --bam, -b        Path to BAM file or directory (if batch mode)"
    echo "  --reference, -r  Path to reference FASTA file (not directory)"
    echo "  --vcf, -v        Path to known-sites VCF file"
    echo "  --out, -o        Output directory"
    echo "  --batch, -t      Enable batch processing"
    echo "  --memory, -m     Set memory limit for Docker container (default: 1GB)"
    echo "  --cpus, -c       Set CPU limit for Docker container (default: 8)"
    echo "  --help, -h       Show this help message"
    exit 0
}

# 解析参数
batch_mode=false
memory_size="1g"
cpu_cores="8"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bam|-b)
            bam_path="$2"
            shift 2
            ;;
        --reference|-r)
            ref_path="$2"
            shift 2
            ;;
        --vcf|-v)
            vcf_path="$2"
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
        --memory|-m)
            memory_size="$2"
            shift 2
            ;;
        --cpus|-c)
            cpu_cores="$2"
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

echo "[DEBUG] Pulling Docker images: broadinstitute/gatk & dukegcb/bwa-samtools"
docker pull broadinstitute/gatk
docker pull dukegcb/bwa-samtools

echo "[DEBUG] BAM path: $bam_path"
echo "[DEBUG] Reference path: $ref_path"
echo "[DEBUG] Known-sites VCF path: $vcf_path"
echo "[DEBUG] Output path: $out_path"
echo "[DEBUG] Batch mode: $batch_mode"
echo "[DEBUG] Memory size: $memory_size"
echo "[DEBUG] CPU cores: $cpu_cores"

# 参数检查
if [[ -z "$bam_path" || -z "$ref_path" || -z "$vcf_path" || -z "$out_path" ]]; then
    echo "Error: Missing required parameters."
    show_help
fi

mkdir -p "$out_path"

# 解析 reference 目录和文件名
ref_dir=$(dirname "$ref_path")
ref_base=$(basename "$ref_path")

# ================================
# **1. 检查 & 生成参考基因组索引**
# ================================
bwa_index_files=(
    "$ref_path.amb"
    "$ref_path.ann"
    "$ref_path.bwt"
    "$ref_path.pac"
    "$ref_path.sa"
)

gatk_index_files=(
    "$ref_path.fai"
    "${ref_path%.fasta}.dict"
)

missing_indexes=()

for file in "${bwa_index_files[@]}" "${gatk_index_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_indexes+=("$file")
    fi
done

if [[ ${#missing_indexes[@]} -gt 0 ]]; then
    echo "[INFO] Missing index files detected. Generating..."
    
    # **创建 BWA 索引**
    if [[ ! -f "$ref_path.bwt" ]]; then
        echo "[INFO] Running bwa index..."
        docker run --rm -v "$ref_dir:/ref" dukegcb/bwa-samtools \
            bwa index /ref/"$ref_base"
    fi

    # **创建 SAMtools FASTA 索引**
    if [[ ! -f "$ref_path.fai" ]]; then
        echo "[INFO] Running samtools faidx..."
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
# **2. 处理 BAM 文件**
# ================================
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

# ================================
# **3. 遍历并执行 BQSR**
# ================================
for bam_file in $bam_files; do
    prefix=$(basename "$bam_file" .bam)
    rg_bam=${temp_dir}
    # **检查 Read Group**
    echo "[INFO] Running RD_detect.sh to add Read Group..."
    output=$(bash "${script_dir}/RD_detect.sh" --bam "$bam_file" -o "$rg_bam")
    echo "bash "${script_dir}/RD_detect.sh" --bam "$bam_file" -o "$rg_bam""
    if echo "$output" | grep -q "RDexist"; then
    	echo "[INFO] Read Group already exists, skipping."
    elif echo "$output" | grep -q "RDAdded"; then
    	echo "[INFO] Read Group was missing and has been added."
    	bam_file=${rg_bam}
    else
    	echo "[ERROR] cant detected if RD exist or not."
    fi

    echo "[INFO] Running BaseRecalibrator for $bam_file"
    docker run --rm --memory="$memory_size" --cpus="$cpu_cores" \
        -v "$(dirname "$bam_file"):/data" \
        -v "$ref_dir:/ref" \
        -v "$(dirname "$vcf_path"):/vcf" \
        -v "$out_path:/out" \
        broadinstitute/gatk \
        gatk BaseRecalibrator \
        -I /data/$(basename "$bam_file") \
        -R /ref/"$ref_base" \
        --known-sites /vcf/$(basename "$vcf_path") \
        -O /out/${prefix}_RG_recal_data.table

    echo "[INFO] Running ApplyBQSR for $bam_file"
    docker run --rm --memory="$memory_size" --cpus="$cpu_cores" \
        -v "$(dirname "$bam_file"):/data" \
        -v "$ref_dir:/ref" \
        -v "$(dirname "$vcf_path"):/vcf" \
        -v "$out_path:/out" \
        broadinstitute/gatk \
        gatk ApplyBQSR \
        -I /data/$(basename "$bam_file") \
        -R /ref/"$ref_base" \
        --bqsr-recal-file /out/${prefix}_RG_recal_data.table \
        -O /out/${prefix}_RG_BQSR.bam

    echo "[INFO] Processed: $bam_file"

    # **清理临时 Read Group BAM 文件**
    echo "[INFO] Removing temporary file: $rg_bam"
    rm -f "$rg_bam"
done

