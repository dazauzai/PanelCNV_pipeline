#!/bin/bash

while getopts "a:" opt; do
    case $opt in
        a) a=${OPTARG} ;;
        *) echo "Usage: $0 -a <cnv-z|decon>" >&2; exit 1 ;;
    esac
done

if [[ ${a} == "cnv-z" ]]; then
    # 必要的 Julia 包列表
    julia_packages=("CSV" "DataFrames" "Statistics")

    # 检查 Julia 包
    missing_packages=()
    for pkg in "${julia_packages[@]}"; do
        if ! julia -e "import Pkg; Pkg.status(\"$pkg\")" &>/dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    # 提示安装缺失的包
    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo "The following Julia packages are missing: ${missing_packages[*]}"
        read -p "Do you want to install them? (T/F): " install_packages
        if [[ "$install_packages" == "T" ]]; then
            for pkg in "${missing_packages[@]}"; do
                julia -e "import Pkg; Pkg.add(\"$pkg\")"
                echo "Installed Julia package: $pkg"
            done
        else
            echo "Package installation skipped. Exiting."
            exit 1
        fi
    fi

    echo "All dependencies for cnv-z are installed."

elif [[ ${a} == "decon" ]]; then
    # 设置 Conda 安装命令和频道
    CONDA_INSTALL="conda install -y"
    CONDA_CHANNELS="-c conda-forge -c defaults -c bioconda"

    # 检查是否已安装 ExomeDepth
    echo "Checking for ExomeDepth..."
    if ! Rscript -e "if (!requireNamespace('ExomeDepth', quietly = TRUE)) quit(status = 1)" > /dev/null 2>&1; then
        echo "ExomeDepth is not installed. Installing..."
        $CONDA_INSTALL r-exomedepth $CONDA_CHANNELS
    else
        echo "ExomeDepth is already installed."
    fi

    # 检查是否已安装 renv
    echo "Checking for renv..."
    if ! Rscript -e "if (!requireNamespace('renv', quietly = TRUE)) quit(status = 1)" > /dev/null 2>&1; then
        echo "renv is not installed. Installing..."
        $CONDA_INSTALL r-renv $CONDA_CHANNELS
    else
        echo "renv is already installed."
    fi

    echo "All dependencies for decon are installed."

else
    echo "No environment checking required for: ${a}"
    exit 0
fi
