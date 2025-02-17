import pandas as pd
import numpy as np
import argparse

# 创建 ArgumentParser 对象
parser = argparse.ArgumentParser(description="接受输入参数")

# 添加参数 -t, -i, -o
parser.add_argument('-t', '--temp_file', type=str, required=True, help='指定临时文件路径')
parser.add_argument('-i', '--indices_file', type=str, required=True, help='指定 non-one indices 文件路径')
parser.add_argument('-o', '--output_file', type=str, required=True, help='指定输出文件路径')

# 解析命令行参数
args = parser.parse_args()

# 使用输入的 -t, -i, -o 参数值
temp_file = args.temp_file
file_path = args.indices_file
output_file = args.output_file

# 打印参数以确认
print(f"临时文件路径: {temp_file}")
print(f"indices 文件路径: {file_path}")
print(f"输出文件路径: {output_file}")
df = pd.read_csv(temp_file, sep="\t", header=None, names=["chr", "start", "value3", "value4", "E"])
with open(file_path, 'r') as f:
    content = f.read().strip()
non_one_indices_list = content.split(',')
# 初始化输出列表
output_data = []
non_one_indices_list1 = ["-2"]
non_one_indices_list2 = non_one_indices_list1 + non_one_indices_list
non_one_indices_list = non_one_indices_list2
for i in range(1, len(non_one_indices_list)):
    element = int(non_one_indices_list[i])+1
    last_element = int(non_one_indices_list[i - 1])+2
    # 获取当前行的 chr, start, end 信息
    chr_value = df.at[element, 'chr']
    end_value = df.at[element, 'start']
    start_value = df.at[last_element, 'start']
    z_values = df.loc[last_element:element, 'value3']
    z_score = z_values.mean() if not z_values.isna().all() else "NaN"
    # 计算 CN
    cn_values = df.loc[last_element:element, 'value4']
    CN = cn_values.mean() if not cn_values.isna().all() else "NaN"
    # 将数据添加到输出列表
    output_data.append([chr_value, start_value, end_value, z_score, CN])

# 保存到输出文件
output_df = pd.DataFrame(output_data, columns=["chr", "start", "end", "z_score", "CN"])
output_df.to_csv(output_file, sep="\t", index=False, header=False)
print(f"Processed file saved at: {output_file}")
