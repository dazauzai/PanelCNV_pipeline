#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import pandas as pd

def main():
    parser = argparse.ArgumentParser(
        description="按 Chr 和连续 Position 合并行，并对数值列取平均值（输入文件带表头）。"
    )
    parser.add_argument("-i", "--input", required=True, help="输入文件路径")
    parser.add_argument("-o", "--output", required=True, help="输出文件路径")
    args = parser.parse_args()

    # 读取数据
    # 假设输入文件以制表符分隔，并在第一行有表头
    # 列名：Chr, Position, Depth, prop, mean, std, expDepth, zscore, copynumber
    df = pd.read_csv(
        args.input,
        sep="\t",
        header=0  # 有表头
    )

    # 根据 Chr, Position 排序（防止原文件中同 Chr 出现乱序）
    df = df.sort_values(by=["Chr", "Position"]).reset_index(drop=True)

    # 为最终结果做一个容器
    results = []

    # 在这里指定需要做平均的列
    # 假设除了 Chr, Position，其余列都做平均
    avg_cols = ["Depth", "prop", "mean", "std", "expDepth", "zscore", "copynumber"]

    # 按 Chr 分组（不同 Chr 之间不会跨区合并）
    for chr_id, sub_df in df.groupby("Chr"):
        # 在每个分组里，根据相邻行是否连续来打“区间”标记
        # shift(1) 取上一行的 Position
        # 只要差值 != 1，就让“连续区间编号”+1
        sub_df["group_id"] = (sub_df["Position"] - sub_df["Position"].shift(1) != 1).cumsum()

        # 对每个 group_id 做聚合
        # - 取 Position 的最小值作为 start
        # - 取 Position 的最大值作为 end
        # - 其余列做平均
        agg_dict = {
            "Chr": "first",          # 同一个 group_id 里的 Chr 都是一样的
            "Position": ["min", "max"]
        }
        for c in avg_cols:
            agg_dict[c] = "mean"

        agg_df = sub_df.groupby("group_id").agg(agg_dict).reset_index(drop=True)

        # groupby+agg 后会产生多重列名，需要扁平化
        agg_df.columns = [
            # "Chr" 列
            "Chr",
            # "Position" 的最小、最大值
            "start",
            "end"
        ] + [
            f"{c}_mean" for c in avg_cols
        ]

        results.append(agg_df)

    # 拼接所有 Chr 的结果
    final_df = pd.concat(results, ignore_index=True)

    # 输出到文件
    # 如果你想保留表头，可以将 he
