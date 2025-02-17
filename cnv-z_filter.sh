#!/bin/bash

# 检查输入参数
while getopts "i:o:a:" opt; do
    case $opt in
        i) input_file=$OPTARG ;;
        o) o=$OPTARG ;;
        a) a=${OPTARG} ;;
        *) echo "Usage: $0 -i <input_file> -o <output_file>" >&2; exit 1 ;;
    esac
done

# 检查输入文件是否存在
if [[ ! -f "$input_file" ]]; then
    echo "Error: Input file '$input_file' does not exist." >&2
    exit 1
fi
script_dir="$(dirname "$(readlink -f "$0")")"
temp=${script_dir}/../temp

# 确保输出文件的路径存在
output_dir=${o%/}
mkdir -p "$output_dir"

# 中间文件路径
temp_file="${temp}/temp_processed_data.tsv"
non_one_indices_file="${temp}/non_one_indices.csv"

# 处理数据，并记录新列 E 不为 1 的行数
processed_data=$(tail -n +2 "$input_file" | awk -F, '$9 != "NaN" {print $1 "\t" $2 "\t" $8 "\t" $9}' | awk '
BEGIN { OFS="\t" }
{
    rows[NR] = $0        # 存储当前行内容
    copynumbers[NR] = $9 # 存储第 4 列 (D 值)
    count = NR           # 记录总行数
    start[NR] = $2       # 存储第 2 列 (B 值)
}
END {
    non_one_indices = ""  # 存储列 E 不为 1 的行号

    # 处理每一行，计算 E 列
    for (i = 1; i < count; i++) {
        delta = start[i+1] - start[i] # 计算 B(B+1) - B(B)
        print rows[i], delta
        if (delta != 1) {
            non_one_indices = non_one_indices i","  # 将行号添加到记录中，用逗号分隔
        }
    }
    # 最后一行，列 E 默认填 1
    print rows[count], 1

    # 打印出列 E 不为 1 的行号
    if (length(non_one_indices) > 0) {
        sub(/,$/, "", non_one_indices)  # 去掉末尾的逗号
        print non_one_indices > "'"${non_one_indices_file}"'"  # 将行号输出到文件
    }
}')

# 保存处理后的数据到中间文件
echo -e "$processed_data" > "$temp_file"

# 检查临时文件是否成功创建
if [[ -f "$temp_file" ]]; then
    echo "Temp file $temp_file exists."
    echo "First 10 lines of temp file:"
    head "$temp_file"
else
    echo "Error: Temp file $temp_file was not created."
    exit 1
fi
echo $"python3 ${script_dir}/filter.py -i $non_one_indices_file -t $temp_file -o ${output_dir}"
python3 ${script_dir}/filter.py -i $non_one_indices_file -t $temp_file -o ${output_dir}/${a}.txt
