script_dir="$(dirname "$(readlink -f "$0")")"
dbSNP="/workspace/dbSNP151.hg38-commonSNP_minFreq5Perc_with_CHR.vcf.gz"
# 解析输入参数
while getopts "b:o:r:n:t:d:e:P:" opt; do
    case $opt in
        b) b=${OPTARG} ;;  # 输入目录
        o) o=${OPTARG} ;;  # 输出目录
        r) r=${OPTARG} ;;  # 参考基因组
        n) n=${OPTARG} ;;
        t) t=${OPTARG} ;;
        d) d=${OPTARG} ;;
        e) e=${OPTARG} ;;
        P) P=${OPTARG} ;;
        *) echo "echo "Usage: $0 -b <bam_directory> -o <output_dir> -r <reference> -n <normal_bam_dir> -t <target_bed_file> -d <dbSNP_for_control_freec> -e <exon_bed> -P <PON_file_for_cnvkit>"" >&2
           exit 1 ;;
    esac
done
# 检查目录是否存在
check_directory() {
    local dir=$1
    if [[ -n "$dir" && ! -d "$dir" ]]; then
        echo "Error: Directory $dir does not exist or is not accessible."
        exit 1
    fi
}
check_mandatory_parameters() {
    # 检查参考基因组（-r）
    if [[ -z "$r" ]]; then
        echo "Error: Reference genome (-r) is not provided. Please specify the path to the reference genome."
        exit 1
    fi
    
    # 检查关键文件（-t）
    if [[ -z "$t" ]]; then
        echo "Error: Required file (-t) is not provided. Please specify the required file."
        exit 1
    fi
}
# 检查文件是否存在，并验证扩展名
check_file() {
    local file=$1
    local ext=$2
    if [[ -n "$file" ]]; then
        if [[ ! -f "$file" ]]; then
            echo "Error: File $file does not exist."
            exit 1
        elif [[ "$file" != *"$ext" ]]; then
            echo "Error: File $file does not have the required extension $ext."
            exit 1
        fi
    fi
}

# 预检 timer.sh
echo "Pre-checking timer.sh..."
bash ${script_dir}/script/timer.sh -a "test" -b 0 -C
if ! bash ${script_dir}/script/timer.sh -a "precheck" -b "0" > /dev/null 2>&1; then
    echo "Error: timer.sh script is not working. Please check its permissions or dependencies."
    exit 1
fi
echo "timer.sh is functional. Proceeding with the main script."
> ${script_dir}/temp/run.log
# 定义 temp 文件夹路径
TIMER_BASE_DIR="${script_dir}/temp"

# 动态获取下一个 batch 号（优化版）
if [[ ! -d "$TIMER_BASE_DIR" ]]; then
    mkdir -p "$TIMER_BASE_DIR"
fi

LAST_BATCH=$(find "${TIMER_BASE_DIR}" -maxdepth 1 -type d -name 'timer*' | sed 's|.*/timer||' | sort -n | tail -1)
if [[ -z "$LAST_BATCH" ]]; then
    batch=1
else
    batch=$((LAST_BATCH + 1))
fi

echo "Using batch number: ${batch}"
mkdir -p "${TIMER_BASE_DIR}/timer${batch}"

# 记录 batch 到 general_log
general_log="${TIMER_BASE_DIR}/run.log"
if [[ ! -w "${general_log}" ]]; then
    touch "${general_log}"
    if [[ $? -ne 0 ]]; then
        echo "Error: Unable to create or write to ${general_log}. Check permissions."
        exit 1
    fi
fi

echo "Batch ${batch} initialized at $(date)" | tee -a "${general_log}"
bash ${script_dir}/script/timer.sh -a "whole_pipeline" -b ${batch}
mkdir -p ${o}
# 检查参数
check_parameters() {
    check_directory "$b" # 检查输入目录
    check_directory "$n" # 检查normal bam目录
    check_file "$r" ".fasta" # 检查参考基因组
    check_file "$t" ".bed"   # 检查BED文件
    check_file "$d" ".vcf"   # 检查VCF文件
    check_file "$P" ".cnn"   # 检查VCF文件
}
general_log=${script_dir}/temp/run.log
touch ${general_log}
# 调用检查函数
check_parameters
gender_list=()
bam_dir=${b%/}
bam_dir=$(readlink -f ${bam_dir})
PON=$(readlink -f ${P})
if [[ -d "${o}" ]]; then
    echo "all paramter set"
else
    echo "please give the paramter -o for output dir"
    exit
fi

for bam_file in "${bam_dir}"/*.bam; do
    if [[ -f "$bam_file" ]]; then
        sample_name=$(basename "${bam_file}" .bam)

        # 询问用户样本的性别
        echo "Please specify sex for sample ${sample_name} (XY/XX):"
        read sex
        if [[ "$sex" != "XY" && "$sex" != "XX" ]]; then
            echo "Invalid input. Defaulting to XY."
            sex="XY"
        fi

        # 将样本名称和性别存储到列表
        gender_list+=("$sample_name" "$sex")
        echo "Stored: $sample_name with sex $sex"
    fi
done
declare -A run_tools  # 用于存储用户的选择

tools=("cnvkit_without_normal" "control_freec_without_control" "control_freec_with_control" \
       "cnvkit_with_normal" "cnv_z" "cnvpanelizer" "panel_cn" "decon")

echo "Please specify whether to run each tool (y/n):"
for tool in "${tools[@]}"; do
    while true; do
        read -p "Do you want to run $tool? (y/n): " choice
        if [[ "$choice" == "y" || "$choice" == "n" ]]; then
            run_tools[$tool]=$choice
            break
        else
            echo "Invalid input. Please enter 'y' or 'n'."
        fi
    done
done
if [[ "${run_tools[cnvkit_without_normal]}" == "y" || "${run_tools[cnvkit_with_normal]}" == "y" ]]; then
    while true; do
        read -p "Which cnvkit method do you want to use? (default/tumor): " cnvkit_method
        if [[ "$cnvkit_method" == "default" || "$cnvkit_method" == "tumor" ]]; then
            break
        else
            echo "Invalid input. Please enter 'default' or 'somatic'."
        fi
    done
    echo "You selected cnvkit method: $cnvkit_method"
fi
check_mandatory_parameters
script_dir="$(dirname "$(readlink -f "$0")")"
temp=${script_dir}/temp
bed_prefix=$(basename ${t} .bed)
output_dir=${o%/}
output_dir=$(readlink -f ${output_dir})
dbSNP=$(readlink -f ${d})
dbSNP2=$(readlink -f ${d2})
normal_dir=${n%/}
normal_dir=$(readlink -f ${normal_dir})
r=$(readlink -f ${r})
mkdir -p ${output_dir}
#cnvkit_without_normal
if [[ "${run_tools[cnvkit_without_normal]}" == "y" ]]; then
    bash ${script_dir}/script/timer.sh -a "cnvkit_without_normal" -b ${batch}
    temp_cnvkit_withoutnormal=${script_dir}/temp/cnvkit_without_normal
    mkdir ${temp_cnvkit_withoutnormal}
    cnvkit_without_normal_log=${temp_cnvkit_withoutnormal}/cnvkit_without_normal.log
    touch ${cnvkit_without_normal_log}
    > ${cnvkit_without_normal_log}\
    mkdir -p ${temp_cnvkit_withoutnormal}
    cd ${temp_cnvkit_withoutnormal}
    echo "cnvkit.py autobin ${bam_dir}/*bam -t ${t} -m amplicon" >> "${cnvkit_without_normal_log}"
    cnvkit.py autobin ${bam_dir}/*bam -t ${t} -m amplicon >> "${cnvkit_without_normal_log}" 2>&1
    if [[ -f "./${bed_prefix}.target.bed" && -f "./${bed_prefix}.antitarget.bed" ]]; then
        target_bed_file_without=$(readlink -f "./${bed_prefix}.target.bed")
        antitarget_bed_file_without=$(readlink -f "./${bed_prefix}.antitarget.bed")
        echo "Use the BED files generated by autobin: ${target_bed_file_without} and ${antitarget_bed_file_without}"
        echo "Use the BED files generated by autobin: ${target_bed_file_without} and ${antitarget_bed_file_without}" >> "${cnvkit_without_normal_log}"
    else
        echo "Error: Cannot find one or both of the BED files generated by autobin."
        [[ ! -f "./${bed_prefix}.target.bed" ]] && echo "Missing: ./${bed_prefix}.target.bed"
        [[ ! -f "../${bed_prefix}.antitarget.bed" ]] && echo "Missing: ./${bed_prefix}.antitarget.bed"
        exit 1
    fi
    mkdir flatref
    cd ./flatref
    echo "Running: cnvkit.py reference -o FlatReference.cnn -f ${r} -t ${target_bed_file_without} -a ${antitarget_bed_file_without}" >> ${cnvkit_without_normal_log}
    cnvkit.py reference -o FlatReference.cnn -f ${r} -t ${target_bed_file_without} -a ${antitarget_bed_file_without} >> ${cnvkit_without_normal_log} 2>&1
    if [[ -f "./FlatReference.cnn" ]]; then
        flat_ref_absolute_path=$(readlink -f "./FlatReference.cnn")
        echo "using flatreference ${flat_ref_absolute_path} for analysis"
        echo "using flatreference ${flat_ref_absolute_path} for analysis" >> "${cnvkit_without_normal_log}"
    else
        echo "can't find the generated flatreference"
    fi
    for bam in ${bam_dir}/*.bam; do
        echo -e "perform cnvkit_without_normal analysis for sampe : ${bam}"
        echo -e "perform cnvkit_without_normal analysis for sampe : ${bam}" >> "${cnvkit_without_normal_log}"
        prefix_cnvkit=$(basename ${bam} .bam)
        mkdir -p ${output_dir}/cnvkit_without_normal/${prefix_cnvkit}
        echo "Running: bash ${script_dir}/script/cnvkit_withnormal.sh -b ${bam} -m ${cnvkit_method} -o ${output_dir}/cnvkit_without_normal/${prefix_cnvkit} -t ${t} -r ${r} -f ${flat_ref_absolute_path} -e ${temp_cnvkit_withoutnormal}" >> ${cnvkit_without_normal_log}
        echo "Running: bash ${script_dir}/script/cnvkit_withnormal.sh -b ${bam} -m ${cnvkit_method} -o ${output_dir}/cnvkit_without_normal/${prefix_cnvkit} -t ${t} -r ${r} -f ${flat_ref_absolute_path} -e ${temp_cnvkit_withoutnormal}"
        bash ${script_dir}/script/cnvkit_withnormal.sh -b ${bam} -m ${cnvkit_method} -o ${output_dir}/cnvkit_without_normal/${prefix_cnvkit} -t ${t} -r ${r} -f ${flat_ref_absolute_path} -e ${temp_cnvkit_withoutnormal} >> ${cnvkit_without_normal_log} 2>&1
    done
    temp=${script_dir}/temp
    bash ${script_dir}/script/timer.sh -a "cnvkit_without_normal" -b ${batch} | tee -a "${general_log}"
else
    echo "Skipping cnvkit_without_normal..."
fi
#control_freec_without_control
if [[ "${run_tools[control_freec_without_control]}" == "y" ]]; then
    bash ${script_dir}/script/timer.sh -a "control_freec_without_control" -b ${batch}
    control_freec_without_control_log=${temp}/control_freec_without_control.log
    touch ${control_freec_without_control_log}
    > ${control_freec_without_control_log}
    mkdir -p ${output_dir}/control_freec/without_normal
    temp=${script_dir}/temp/control_freec_without_control
    mkdir -p ${temp}
    chromosomes=($(awk '{print $1}' ${t} | sort | uniq))
    count=0
    mkdir -p ${temp}/chr
    > ${temp}/chrlen.bed
    for chromosome in "${chromosomes[@]}"; do
        count=$((count + 1))
        len=$(awk -v chr="$chromosome" '$1 == chr {print $2}' ${r}.fai)
        echo -e "${count}\t${chromosome}\t${len}" >> ${temp}/chrlen.bed
        samtools faidx ${r} "${chromosome}" > ${temp}/chr/${chromosome}.fasta
    done
    chrlen=$(readlink -f "${temp}/chrlen.bed")
    chr=$(readlink -f "${temp}/chr")
    # 遍历 BAM 文件目录，生成 config 文件
    for bam_file in "${bam_dir}"/*.bam; do
        echo -e "perform control_freec_without_control analysis for sample: ${bam_file}"
        if [[ -f "$bam_file" ]]; then
            sample_name=$(basename "${bam_file}" .bam)
            config_file="${temp}/${sample_name}.config"
            mkdir -p ${output_dir}/control_freec/without_normal/${sample_name}
            for ((i=0; i<${#gender_list[@]}; i+=2)); do
                if [[ "${gender_list[i]}" == "$sample_name" ]]; then
                    sex="${gender_list[i+1]}"
                    break
                fi
            done
            # 生成 config 文件
            cat > "${config_file}" <<EOF
[general]

chrLenFile = ${temp}/chrlen.bed
BedGraphOutput = TRUE
degree = 4
forceGCcontentNormalization = 1
intercept = 1
minCNAlength = 3
maxThreads = 8
noisyData = TRUE
outputDir = ${output_dir}/control_freec/without_normal/${sample_name}
ploidy = 2,3,4
printNA = FALSE
readCountThreshold = 100
sex = ${sex}
window = 0
breakPointThreshold = 0.8
chrFiles = ${chr}

[sample]

mateFile = ${bam_file}
inputFormat = BAM
mateOrientation = FR

[BAF]

makePileup = ${dbSNP}
SNPfile = ${dbSNP}
fastaFile = ${r}

[target]

captureRegions = ${t}
EOF

            echo "Config file created: ${config_file}"
        fi
        echo "Running FreeC for sample: ${sample_name}" >> ${control_freec_without_control_log}
        echo "freec -conf ${config_file}" >> ${control_freec_without_control_log}
        freec -conf ${config_file} >> ${control_freec_without_control_log} 2>&1
        if [[ $? -ne 0 ]]; then
            echo "Error: FreeC failed for sample ${sample_name}. Check ${control_freec_without_control_log}" >> ${control_freec_without_control_log}
            continue
        fi
    done
    bash ${script_dir}/script/timer.sh -a "control_freec_without_control" -b ${batch} | tee -a "${general_log}"
else
    echo "Skipping control_freec_without_control..."
fi
temp=${script_dir}/temp
#control_freec_with_control
if [[ "${run_tools[control_freec_with_control]}" == "y" ]]; then
    bash ${script_dir}/script/timer.sh -a "control_freec_with_control" -b ${batch}
    control_freec_with_control_log=${script_dir}/temp/control_freec_with_control.log
    touch ${control_freec_with_control_log}
    > ${control_freec_with_control_log}
    # 获取文件大小和路径，按大小排序
    mkdir -p ${output_dir}/control_freec/with_normal
    temp=${script_dir}/temp/control_freec_with_control
    mkdir -p ${temp}
    chromosomes=($(awk '{print $1}' ${t} | sort | uniq))
    count=0
    mkdir -p ${temp}/chr
    > ${temp}/chrlen.bed
    for chromosome in "${chromosomes[@]}"; do
        count=$((count + 1))
        len=$(awk -v chr="$chromosome" '$1 == chr {print $2}' ${r}.fai)
        echo -e "${count}\t${chromosome}\t${len}" >> ${temp}/chrlen.bed
        samtools faidx ${r} "${chromosome}" > ${temp}/chr/${chromosome}.fasta
    done
    chrlen=$(readlink -f "${temp}/chrlen.bed")
    chr=$(readlink -f "${temp}/chr")
    # 找到 normal 文件夹中所有 BAM 文件并按大小排序
    files=($(find "$normal_dir" -type f -name "*.bam" -exec ls -lS {} + | awk '{print $9}'))
    chromosomes=($(awk '{print $1}' ${t} | sort | uniq))
    # 计算文件总数
    file_count=${#files[@]}

    if (( file_count == 0 )); then
        echo "No BAM files found in ${normal_dir}"
        exit 1
    fi

    # 获取中间索引
    if (( file_count % 2 == 0 )); then
        mid_index=$((file_count / 2 - 1))  # 偶数时选择偏左的文件
    else
        mid_index=$((file_count / 2))      # 奇数时选择正中间的文件
    fi

    # 选择中间大小的文件
    selected_file=${files[mid_index]}
    echo "Selected normal for control_freec: ${selected_file}"
    for bam_file in "${bam_dir}"/*.bam; do
        echo -e "perform control_freec_with_control analysis for sample: ${bam_file}"
        if [[ -f "$bam_file" ]]; then
            sample_name=$(basename "${bam_file}" .bam)
            config_file="${temp}/${sample_name}.config"
            mkdir ${output_dir}/control_freec/with_normal/${sample_name}
            for ((i=0; i<${#gender_list[@]}; i+=2)); do
                if [[ "${gender_list[i]}" == "$sample_name" ]]; then
                    sex="${gender_list[i+1]}"
                    break
                fi
            done
            # 生成 config 文件
            cat > "${config_file}" <<EOF
[general]

chrLenFile = ${chrlen}
BedGraphOutput = TRUE
degree = 1
forceGCcontentNormalization = 1
intercept = 1
minCNAlength = 3
maxThreads = 8
noisyData = TRUE
outputDir = ${output_dir}/control_freec/with_normal/${sample_name}
ploidy = 2,3,4
printNA = FALSE
readCountThreshold = 100
sex = ${sex}
window = 0
breakPointThreshold = 0.8
chrFiles = ${chr}

[sample]

mateFile = ${bam_file}
inputFormat = BAM
mateOrientation = FR

[control]

mateFile = ${selected_file}
inputFormat = BAM
mateOrientation = FR

[BAF]

makePileup = ${dbSNP}
SNPfile = ${dbSNP}
fastaFile = ${r}

[target]

captureRegions = ${t}
EOF

            echo "Config file created: ${config_file}"
        fi
        echo "Running FreeC for sample: ${sample_name}" >> ${control_freec_with_control_log}
        echo "freec -conf ${config_file}" >> ${control_freec_with_control_log}
        freec -conf ${config_file} >> ${control_freec_with_control_log} 2>&1
        if [[ $? -ne 0 ]]; then
            echo "Error: FreeC failed for sample ${sample_name}. Check ${control_freec_without_control_log}" >> ${control_freec_with_control_log}
            continue
        fi
    done
    bash ${script_dir}/script/timer.sh -a "control_freec_with_control" -b ${batch} | tee -a ${general_log}
else
    echo "Skipping control_freec_with_control..."
fi
temp=${script_dir}/temp
#cnvkit_withnormal
if [[ "${run_tools[cnvkit_with_normal]}" == "y" ]]; then
    bash ${script_dir}/script/timer.sh -a "cnvkit_withnormal" -b ${batch}
    temp_cnvkit_withnormal=${script_dir}/temp/cnvkit_withnormal
    mkdir -p ${temp_cnvkit_withnormal}
    cnvkit_with_normal_log=${temp_cnvkit_withnormal}/cnvkit_withnormal.log
    touch ${cnvkit_with_normal_log}
    > ${cnvkit_with_normal_log}
    cd ${temp_cnvkit_withnormal}
    echo "cnvkit.py autobin ${bam_dir}/*bam -t ${t} -m amplicon" >> ${cnvkit_with_normal_log}
    cnvkit.py autobin ${bam_dir}/*bam -t ${t} -m amplicon >> ${cnvkit_with_normal_log} 2>&1
    mkdir -p ${temp_cnvkit_withnormal}/normal
    cd ${temp_cnvkit_withnormal}/normal
    if [[ -f "${PON}" ]]; then
        echo "use ${PON} as input panel of normal"
    else
        for normal in ${normal_dir}/*.bam; do
            echo -e "calculate cnvkit_withnormal analysis for sample : ${normal}"
            normal_prefix=$(basename ${normal} .bam)
            echo "cnvkit.py coverage ${normal} ../${bed_prefix}.target.bed -o ${normal_prefix}.targetcoverage.cnn" >> ${cnvkit_with_normal_log}
            cnvkit.py coverage ${normal} ../${bed_prefix}.target.bed -o ${normal_prefix}.targetcoverage.cnn >> ${cnvkit_with_normal_log} 2>&1
            cnvkit.py coverage ${normal} ../${bed_prefix}.antitarget.bed -o ${normal_prefix}.antitargetcoverage.cnn >> ${cnvkit_with_normal_log} 2>&1
        done
        echo "cnvkit.py reference *.targetcoverage.cnn *.antitargetcoverage.cnn --fasta ${r} -o ../my_reference.cnn" >> ${cnvkit_with_normal_log}
        cnvkit.py reference *.targetcoverage.cnn *.antitargetcoverage.cnn --fasta ${r} -o ../my_reference.cnn >> ${cnvkit_with_normal_log} 2>&1
        ref_absolute_path=$(readlink -f "../my_reference.cnn")
    fi
    mkdir -p ${output_dir}/cnvkit_with_normal
    for bam in ${bam_dir}/*.bam; do
        echo -e "perform cnvkit_withnormal analysis for sample : ${bam}"
        prefix_cnvkit=$(basename ${bam} .bam)
        mkdir -p ${output_dir}/cnvkit_with_normal/${prefix_cnvkit}
        if [[ -f ${PON} ]]; then
            f_option=${PON}
        else
            f_option=${ref_absolute_path}
        fi
        echo "bash ${script_dir}/script/cnvkit_withnormal.sh -b ${bam} -o ${output_dir}/cnvkit_with_normal/${prefix_cnvkit} -m ${cnvkit_method} -t ${t} -r ${r} -f ${f_option} -e ${temp_cnvkit_withnormal}" >> ${cnvkit_with_normal_log}
        bash ${script_dir}/script/cnvkit_withnormal.sh -b ${bam} -o ${output_dir}/cnvkit_with_normal/${prefix_cnvkit} -m ${cnvkit_method} -t ${t} -r ${r} -f ${f_option} -e ${temp_cnvkit_withnormal} >> ${cnvkit_with_normal_log} 2>&1
    done
    bash ${script_dir}/script/timer.sh -a "cnvkit_withnormal" -b ${batch} | tee -a ${general_log}
else
    echo "Skipping cnvkit_with_normal..."
fi
#cnv_z
if [[ "${run_tools[cnv_z]}" == "y" ]]; then
    bash ${script_dir}/script/timer.sh -a "cnv_z" -b ${batch}
    temp=${script_dir}/temp
    cnv_z_log=${temp}/cnv_z.log
    touch ${cnv_z_log}
    > ${cnv_z_log}
    echo -e "perform cnv_z analysis for sample in ${bam_dir}"
    mkdir -p "${output_dir}"/cnv-z
    cd "${output_dir}"/cnv-z
    echo $"julia -t 8 ${script_dir}/script/CNV-Z_debug.jl ${t} ${bam_dir} ${script_dir}/script/header.txt "${output_dir}"/cnv-z" >> ${cnv_z_log}
    julia -t 8 ${script_dir}/script/CNV-Z_debug.jl ${t} ${bam_dir} ${script_dir}/script/header.txt "${output_dir}"/cnv-z >> ${cnv_z_log} 2>&1
    mkdir -p ${output_dir}/cnv-z/mean_filter
      #mean_process
    for temp in ./*.csv ;do
        echo "generate standard output file for cnv_z without filter via mean process"
        prefix_cnvz=$(basename ${temp} .csv)
        echo "Rscript ${script_dir}/script/filter.R  ${temp} ${output_dir}/cnv-z/mean_filter/${prefix_cnvz}"
        Rscript ${script_dir}/script/filter.R  ${temp} ${output_dir}/cnv-z/mean_filter/${prefix_cnvz} >> ${cnv_z_log} 2>&1
    done
    #default_filter
    echo "Using the default filter of CNV-Z"
    mkdir -p "${output_dir}"/cnv-z/default_filter
    julia -t 8 ${script_dir}/script/cnvz_default_filter.jl ${e} "${output_dir}"/cnv-z "${output_dir}"/cnv-z/default_filter >> ${cnv_z_log} 2>&1
    bash ${script_dir}/script/timer.sh -a "cnv_z" -b ${batch} | tee -a ${general_log}
else
    echo "Skipping CNV-Z..."
fi



#cnvpanelizer
if [[ "${run_tools[cnvpanelizer]}" == "y" ]]; then
    bash ${script_dir}/script/timer.sh -a "cnvpanelizer" -b ${batch}
    echo "Checking the environment for cnvpanelizer..."
    Rscript ${script_dir}/script/check_env.R cnvpanelizer
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to set up the environment for panelcn.mops. Check the logs."
        exit 1
    fi

    cnvpanelizerlog=${script_dir}/temp/cnvpanelizer.log
    touch ${cnvpanelizerlog}
    > ${cnvpanelizerlog}
    echo -e "perform cnvpanelizer analysis with bed file : ${e}"
    mkdir -p ${output_dir}/cnv_panelizer
    echo "Rscript ${script_dir}/script/cnv_panelizer.R ${bam_dir} ${normal_dir} ${t} ${output_dir}/cnv_panelizer" >> ${cnvpanelizerlog}
    Rscript ${script_dir}/script/cnv_panelizer.R ${bam_dir} ${normal_dir} ${t} ${output_dir}/cnv_panelizer >> ${cnvpanelizerlog} 2>&1
    bash ${script_dir}/script/timer.sh -a "cnvpanelizer" -b ${batch} | tee -a ${general_log}
else
    echo "Skipping cnvpanelizer..."
fi


#panel.cn
if [[ "${run_tools[panel_cn]}" == "y" ]]; then
    bash ${script_dir}/script/timer.sh -a "panelcn" -b ${batch}
    echo "Checking the environment for panelcn.mops..."
    temp=${script_dir}/temp
    # 日志和目录准备
    panelcn_log="${temp}/panelcn.log"
    mkdir -p "$(dirname "${panelcn_log}")"
    > "${panelcn_log}"

    echo -e "Performing panel.cn analysis with bed file: ${e}" | tee -a "${panelcn_log}"
    mkdir -p "${output_dir}/panel_cn"
    cd "${output_dir}/panel_cn"

    # 调用分析脚本
    echo "Rscript ${script_dir}/script/panel_cn.R ${bam_dir} ${normal_dir} ${e}" >> "${panelcn_log}"
    Rscript "${script_dir}/script/panel_cn.R" "${bam_dir}" "${normal_dir}" "${e}" >> "${panelcn_log}" 2>&1

    # 检查结果状态
    if [[ $? -eq 0 ]]; then
        echo "panel.cn analysis completed successfully." | tee -a "${panelcn_log}"
    else
        echo "Error: panel.cn analysis failed. Check the logs for details." | tee -a "${panelcn_log}"
    fi
    bash ${script_dir}/script/timer.sh -a "panelcn" -b ${batch} | tee -a ${general_log}
else
    echo "Skipping panel.cn"
fi


#decon
if [[ "${run_tools[decon]}" == "y" ]]; then
    bash ${script_dir}/script/timer.sh -a "decon" -b ${batch}
    echo "Checking the environment for decon..."
    
    # 调用 R 脚本检查和安装依赖
    Rscript "${script_dir}/script/check_env.R" decon
    decon_log=${temp}/decon.log
    touch ${decon_log}
    > ${decon_log}
    echo -e "perform decon analysis with bed file : ${t}"
    mkdir -p ${output_dir}/decon/plot
    echo "Rscript ${script_dir}/script/decon_step1.R --bams ${bam_dir} \
                        --bed ${t} \
                        --fasta ${r} \
                        --out ${temp}/output_counts" >> ${decon_log}
    Rscript ${script_dir}/script/decon_step1.R --bams ${bam_dir} \
                        --bed ${e} \
                        --fasta ${r} \
                        --out ${temp}/output >> ${decon_log} 2>&1
    echo "Rscript ${script_dir}/script/decon_step2.R --RData ${temp}/output_counts.RData \
                        --out ${output_dir}/decon \
                        --plotFolder ${output_dir}/decon/plot" >> ${decon_log} 2>&1
    Rscript ${script_dir}/script/decon_step2.R --RData ${temp}/output_counts.RData \
                        --out ${output_dir}/decon \
                        --plotFolder ${output_dir}/decon/plot >> ${decon_log} 2>&1
    bash ${script_dir}/script/timer.sh -a "decon" -b ${batch} | tee -a ${general_log}
else
    echo "Skipping decon"
fi
find ${output_dir} -type d -empty -name "cnvkit_withoutput_normal" -exec rmdir {} \;
bash ${script_dir}/script/timer.sh -a "whole_pipeline" -b ${batch} | tee -a ${general_log}
bash ${script_dir}/script/timer.sh -a "whole_pipeline" -b ${batch} -C
bash ${script_dir}/script/timer.sh -a "whole_pipeline" -b 0 -C
