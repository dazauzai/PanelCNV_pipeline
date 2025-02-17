# 加载必要的库
if (!requireNamespace("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install("CNVPanelizer")
library(CNVPanelizer)

# 获取命令行参数
args <- commandArgs(trailingOnly = TRUE)

# 参数顺序：bam文件夹 reference文件夹 bed路径 outputdir
if (length(args) != 4) {
  stop("需要四个参数：bam 文件夹、reference 文件夹、bed 文件路径、outputdir")
}

sampleDirectory <- args[1]  # 样本 BAM 文件夹路径
referenceDirectory <- args[2]  # 参考 BAM 文件夹路径
bedFilepath <- args[3]  # BED 文件路径
outputDir <- args[4]  # 输出目录

# 确保输出目录存在
if (!dir.exists(outputDir)) {
  dir.create(outputDir, recursive = TRUE)
}

# 提取 BED 文件中的基因组信息
amplColumnNumber <- 4
genomicRangesFromBed <- BedToGenomicRanges(bedFilepath,
                                           ampliconColumn = amplColumnNumber,
                                           split = "_")

# 提取基因名和扩增子名
metadataFromGenomicRanges <- elementMetadata(genomicRangesFromBed)
geneNames <- metadataFromGenomicRanges["geneNames"][, 1]
ampliconNames <- metadataFromGenomicRanges["ampliconNames"][, 1]

# 获取样本和参考 BAM 文件路径
sampleFilenames <- list.files(path = sampleDirectory, pattern = ".bam$", full.names = TRUE)
referenceFilenames <- list.files(path = referenceDirectory, pattern = ".bam$", full.names = TRUE)

# 检查 BAM 文件是否存在
if (length(sampleFilenames) == 0) stop("样本 BAM 文件夹中没有找到 .bam 文件")
if (length(referenceFilenames) == 0) stop("参考 BAM 文件夹中没有找到 .bam 文件")

# 是否去除 PCR 重复
removePcrDuplicates <- FALSE  # TRUE 适用于 Ion Torrent 数据

# 读取参考数据集
referenceReadCounts <- ReadCountsFromBam(referenceFilenames,
                                         genomicRangesFromBed,
                                         sampleNames = referenceFilenames,
                                         ampliconNames = ampliconNames,
                                         removeDup = removePcrDuplicates)

# 读取样本数据集
sampleReadCounts <- ReadCountsFromBam(sampleFilenames,
                                      genomicRangesFromBed,
                                      sampleNames = sampleFilenames,
                                      ampliconNames = ampliconNames,
                                      removeDup = removePcrDuplicates)

# 确保基因名和行名一致
geneNames <- row.names(referenceReadCounts)

# 运行 CNVPanelizer 分析
CNVPanelizerFromReadCountsHELPER(
  sampleReadCounts = sampleReadCounts,
  referenceReadCounts = referenceReadCounts,
  genomicRangesFromBed = genomicRangesFromBed,
  numberOfBootstrapReplicates = 10000,
  normalizationMethod = "tmm",
  robust = TRUE,
  backgroundSignificanceLevel = 0.05,
  outputDir = outputDir,
  splitSize = 5
)

# 提示完成
cat("CNVPanelizer 分析完成，结果已输出至：", outputDir, "\n")
