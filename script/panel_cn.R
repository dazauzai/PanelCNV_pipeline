# 定义必要的包列表
required_packages <- c("panelcn.mops", "plyr")

# 检查并安装缺失的包
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, repos = "http://cran.r-project.org")  # 安装CRAN包
    library(pkg, character.only = TRUE)
  }
}

if (!require("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

BiocManager::install("panelcn.mops")

# 加载必要的库
library(panelcn.mops)
library(plyr)

# 获取命令行参数
args <- commandArgs(trailingOnly = TRUE)

# 参数解析
if (length(args) < 3) {
  stop("Usage: Rscript script_name.R <test_dir> <control_dir> <bed_path>")
}

test_dir <- args[1]
control_dir <- args[2]
bed_path <- args[3]

# 打印参数以便调试
print(paste("Test BAM Directory:", test_dir))
print(paste("Control BAM Directory:", control_dir))
print(paste("BED File Path:", bed_path))

# 加载 BED 文件
countWindows <- getWindows(bed_path)

# 获取 BAM 文件列表
test.bam <- list.files(path = test_dir, pattern = ".bam$", full.names = TRUE)
control.bam <- list.files(path = control_dir, pattern = ".bam$", full.names = TRUE)

# 检查 BAM 文件是否加载成功
if (length(test.bam) == 0) stop("No test BAM files found in directory: ", test_dir)
if (length(control.bam) == 0) stop("No control BAM files found in directory: ", control_dir)

# 读取 BAM 文件中的覆盖计数
test <- countBamListInGRanges(countWindows = countWindows,
                              bam.files = test.bam, read.width = 150)
control <- countBamListInGRanges(countWindows = countWindows,
                                 bam.files = control.bam, read.width = 150)

# 合并 Test 和 Control 数据
XandCB <- test
elementMetadata(XandCB) <- cbind(elementMetadata(XandCB), elementMetadata(control))

# 运行 CNV 检测
resultlist <- runPanelcnMops(XandCB, 
                             testiv = 1:ncol(elementMetadata(test)), 
                             countWindows = countWindows, 
                             maxControls = 200)

# 创建结果表
sampleNames <- colnames(elementMetadata(test))
finalResultsTable <- createResultTable(resultlist = resultlist, 
                                       XandCB = XandCB, 
                                       countWindows = countWindows, 
                                       sampleNames = sampleNames)

# 合并结果
allResults <- ldply(finalResultsTable, data.frame)

# 保存结果
output_file <- "panelcn_output.txt"
write.table(allResults, sep = "\t", quote = FALSE, row.names = FALSE, file = output_file)
