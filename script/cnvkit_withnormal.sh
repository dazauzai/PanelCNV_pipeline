#!/bin/bash

# 解析输入参数
while getopts "b:o:r:n:t:m:f:e:" opt; do
    case $opt in
        b) b=${OPTARG} ;;  # 输入目录
        o) o=${OPTARG} ;;  # 输出目录
        r) r=${OPTARG} ;;  # 参考基因组
        n) n=${OPTARG} ;;
        t) t=${OPTARG} ;;
        m) m=${OPTARG} ;;
        f) f=${OPTARG} ;;
        e) e=${OPTARG} ;;
        *) echo "Usage: $0 -b <bam_directory> -o <output_dir> -r <reference>" >&2
           exit 1 ;;
    esac
done
bed_prefix=$(basename ${t} .bed)
normal_dir=${n%/}
script_dir="$(dirname "$(readlink -f "$0")")"
temp=${e}
prefix=$(basename ${b} .bam)
cd ${temp}
if [[ $m == "tumor" ]]; then
    bin_filter="--drop-low-coverage"
    m_seg="hmm-tumor"
else
    bin_filter="--drop-outliers"
    m_seg="cbs"
fi

# For each sample...
cnvkit.py coverage ${b} ${temp}/${bed_prefix}.target.bed -o ${temp}/${prefix}.targetcoverage.cnn
cnvkit.py coverage ${b} ${temp}/${bed_prefix}.antitarget.bed -o ${temp}/${prefix}.antitargetcoverage.cnn
# For each tumor sample...
cnvkit.py fix ${temp}/${prefix}.targetcoverage.cnn ${temp}/${prefix}.antitargetcoverage.cnn ${f} -o ${temp}/${prefix}.cnr
cnvkit.py segment ${temp}/${prefix}.cnr -o ${temp}/${prefix}.cns
cnvkit.py call ${temp}/${prefix}.cns -o ${o}/${prefix}.call.cns
# Optionally, with --scatter and --diagram
cnvkit.py scatter ${temp}/${prefix}.cnr -s ${temp}/${prefix}.cns -o ${o}/${prefix}-scatter.pdf
cnvkit.py diagram ${temp}/${prefix}.cnr -s ${temp}/${prefix}.cns -o ${o}/${prefix}-diagram.pdf
