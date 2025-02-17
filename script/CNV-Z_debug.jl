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

# Usage example: julia -t 8 script.jl <bed_file> <bam_dir> <output_dir>
if length(ARGS) < 4
    println("Usage: julia script.jl <bed_file> <bam_dir> <output_dir>")
    exit(1)
end

# 获取参数
bed_file = ARGS[1]
bam_dir = ARGS[2]
header_file = ARGS[3]
output_dir = ARGS[4]

# 确保输出目录存在
if !isdir(output_dir)
    println("Creating output directory: $output_dir")
    mkdir(output_dir)
end

# 获取 BAM 文件列表
bam_files = glob("*.bam", bam_dir)
println("Found BAM files: ", bam_files)

# 多线程处理
Threads.@threads for bam_file in bam_files
    sample_name = splitext(basename(bam_file))[1]
    output_file = joinpath(output_dir, "mdepth-$sample_name.txt")

    println("Processing BAM file: $bam_file")
    println("Output file: $output_file")

    open(output_file, "w") do io
        cmd = `samtools depth -a -b $bed_file $bam_file`
        println("Executing command: $cmd")
        write(io, read(cmd))
    end
end

for bam_file in bam_files
    sample_name = splitext(basename(bam_file))[1]
    input_file = joinpath(output_dir, "mdepth-$sample_name.txt")
    output_file = joinpath(output_dir, "mdepth-$sample_name.h.txt")

    println("Combining header and depth file for sample: $sample_name")
    println("Header file: $header_file")
    println("Input file: $input_file")
    println("Output file: $output_file")

    open(output_file, "w") do io
        write(io, read(`cat $header_file $input_file`))
    end
end

Files = []

for bam_file in bam_files
    sample_name = splitext(basename(bam_file))[1]
    file_path = joinpath(output_dir, "mdepth-$sample_name.h.txt")
    println("Adding file to list: $file_path")
    push!(Files, file_path)
end

Fx = [DataFrame(CSV.File(f)) for f in Files]
println("Loaded DataFrames:")
for i in 1:length(Fx)
    println("DataFrame $i columns: ", names(Fx[i]))
    println(Fx[i])
end

function normgene(chr, pos)::Bool
    ichr = chr != "chrX"
    ipos = pos > 0
    return ichr && ipos
end

for i in 1:length(Files)
    println("Calculating 'prop' for DataFrame $i")
    Fx[i][!,:prop] = Fx[i][!,:Depth] / sum(filter([:Chr, :Position] => normgene, Fx[i])[!,:Depth])
    println("DataFrame $i after 'prop':")
    println(Fx[i])
end

M = Matrix{Float64}(undef, size(Fx[1], 1), length(Fx))
println("Initialized Matrix M with size: ", size(M))

for i in 1:length(Fx)
    println("Filling column $i of Matrix M")
    M[:,i] = Fx[i][:,:prop]
end

for i in 1:size(M,2)
    println("Calculating 'mean' for column $i")
    Fx[i][!,:mean] = [mean(M[j,:]) for j in 1:size(M,1)]
    println("DataFrame $i after 'mean':")
    println(Fx[i])
end

for i in 1:size(M,2)
    println("Calculating 'std' for column $i")
    Fx[i][!,:std] = [std(M[j,:]) for j in 1:size(M,1)]
    println("DataFrame $i after 'std':")
    println(Fx[i])
end

for i in 1:size(M,2)
    println("Calculating 'expDepth' for column $i")
    Fx[i][!,:expDepth] = [Fx[i][j,:Depth] / Fx[i][j,:prop] * Fx[i][j,:mean] for j in 1:size(M,1)]
    println("DataFrame $i after 'expDepth':")
    println(Fx[i])
end

for i in 1:size(M,2)
    println("Calculating 'zscore' for column $i")
    Fx[i][!,:zscore] = [(Fx[i][j,:prop] - Fx[i][j,:mean]) / Fx[i][j,:std] for j in 1:size(M,1)]
    println("DataFrame $i after 'zscore':")
    println(Fx[i])
end

for i in 1:size(M,2)
    println("Calculating 'copynumber' for column $i")
    Fx[i][!,:copynumber] = [2 * Fx[i][j,:prop] / Fx[i][j,:mean] for j in 1:size(M,1)]
    println("DataFrame $i after 'copynumber':")
    println(Fx[i])
end

println("Final DataFrames before writing:")
for i in 1:length(Fx)
    println("DataFrame $i columns: ", names(Fx[i]))
    println(Fx[i])
end

for i in 1:length(Files)
    name = splitext(basename(Files[i]))[1]
    output_csv = "Fx-$name.csv"
    println("Writing DataFrame $i to $output_csv")
    CSV.write(output_csv, Fx[i], bufsize = 2^24)
end
