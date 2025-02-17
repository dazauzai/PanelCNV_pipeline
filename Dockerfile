FROM continuumio/miniconda3

# 设置工作目录
WORKDIR /workspace

# 添加 Conda 频道
RUN conda config --add channels defaults && \
    conda config --add channels bioconda && \
    conda config --add channels conda-forge

# 创建 Conda 环境并安装 Python 3.7
RUN conda create -n py37_env python=3.7 --override-channels -c conda-forge -c defaults

# 安装所需的软件包（使用 conda run 确保环境正确）
RUN conda run -n py37_env conda install -y pomegranate pandas=1.0.5 cnvkit bedtools samtools

# 安装构建工具（用于编译 FREEC）
RUN apt-get update && apt-get install -y build-essential wget
RUN conda install -y -c conda-forge r-base
# 下载 FREEC 并编译
RUN wget https://github.com/BoevaLab/FREEC/archive/refs/tags/v11.6.tar.gz && \
    tar -zxvf v11.6.tar.gz && \
    cd FREEC-11.6/src && \
    make
RUN wget https://cloud.inf.ethz.ch/s/idTaGpZdnS9To5c/download/dbSNP151.hg38-commonSNP_minFreq5Perc_with_CHR.vcf.gz
# 添加 FREEC 到环境变量
RUN echo 'export PATH=/workspace/FREEC-11.6/src:$PATH' >> ~/.bashrc
# 设置默认环境
ENV PATH="/opt/conda/envs/py37_env/bin:/workspace/FREEC-11.6/src:$PATH"
RUN mkdir -p $CONDA_PREFIX/lib/R/etc/ && \
    echo 'options(repos = c(CRAN="https://cloud.r-project.org/"))' >> $CONDA_PREFIX/lib/R/etc/Rprofile.site

# 安装 R 相关依赖
RUN R -e "install.packages('BiocManager', repos='https://cloud.r-project.org/')"
RUN R -e "BiocManager::install(version = '3.16', ask=FALSE)"
RUN R -e "install.packages(c('R.utils', 'optparse', 'data.table'), repos='https://cloud.r-project.org/')"

# 安装 Bioconductor 依赖
RUN R -e "BiocManager::install(c('panelcn.mops', 'CNVPanelizer', 'ExomeDepth'), ask=FALSE)"

RUN apt-get update && apt-get install -y wget ca-certificates && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/1.9/julia-1.9.3-linux-x86_64.tar.gz && \
    tar -xzf julia-1.9.3-linux-x86_64.tar.gz -C /usr/local/ && \
    ln -s /usr/local/julia-1.9.3/bin/julia /usr/local/bin/julia && \
    rm julia-1.9.3-linux-x86_64.tar.gz
# 进入 shell
CMD ["/bin/bash"]

