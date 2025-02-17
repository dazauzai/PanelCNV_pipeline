#!/usr/bin/env julia

# Import required package management
import Pkg

# 确保环境激活并安装依赖
Pkg.activate(".")
Pkg.instantiate()

required_packages = ["CSV", "DataFrames", "Statistics", "Glob"]
for pkg in required_packages
    if !haskey(Pkg.installed(), pkg)
        Pkg.add(pkg)
    end
end

using CSV, DataFrames, Statistics, Glob, Base.Threads
# 参数检查
if length(ARGS) < 3
    println("Usage: julia script.jl <bed_file> <bam_dir> <header_file> <output_dir>")
    exit(1)
end

bed_file = ARGS[1]
bam_dir = ARGS[2]
output_dir = ARGS[3]
bam_files = glob("*.csv", bam_dir)
println("Step 1: Found $(length(bam_files)) BAM files.")

# 多线程处理
Threads.@threads for bam_file in bam_files
    sample_name = splitext(basename(bam_file))[1]
    sample_output_dir = joinpath(output_dir, sample_name)
    mkpath(sample_output_dir)

    # 读取样本 CSV
    df_path = joinpath(bam_dir, "$sample_name.csv")
    if !isfile(df_path)
        println("Warning: Sample CSV '$df_path' not found, skipping.")
        continue
    end
    df = DataFrame(CSV.File(df_path))
    filter_file = joinpath(sample_output_dir, "Fx-$sample_name.filter2.3.csv")
    CSV.write(filter_file, filter([:copynumber, :zscore] => (y, z) -> (y < 1.2 || y > 2.8) && abs(z) >= 2.3, df))

    # 读取 BED 文件
    dft = DataFrame(CSV.File(bed_file, header=false, delim='\t'))
    dft.len = dft[:, 3] - dft[:, 2]
    dft.idx = collect(1:nrow(dft))
    dft.hits = zeros(Int64, nrow(dft))
    dft.zscore = zeros(Float64, nrow(dft))

    # 统计命中次数和 Z-score
    open(filter_file) do f1
        lines = readlines(f1)
        for i in 2:length(lines)
            line = split(lines[i], ",")
            chrom = line[1]
            pos = parse(Int64, line[2])
            for j in 1:nrow(dft)
                if dft[j, 1] == chrom && dft[j, 2] < pos && dft[j, 3] >= pos
                    dft[j, :hits] += 1
                end
            end
        end
        for i in 1:nrow(dft)
            local Z = Float64[]
            for j in 2:length(lines)
                line = split(lines[j], ",")
                chrom = line[1]
                pos = parse(Int64, line[2])
                score = parse(Float64, line[8])
                if dft[i, 1] == chrom && dft[i, 2] < pos && dft[i, 3] >= pos
                    push!(Z, score)
                end
            end
            dft[i, :zscore] = mean(Z)
        end
    end

    # 保存结果
    dff = filter(:hits => x -> x > 0, dft)
    output_file = joinpath(sample_output_dir, "Fx-$sample_name.res.2.3.csv")
    CSV.write(output_file, dff)
end
