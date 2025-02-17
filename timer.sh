#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"

# 参数解析
CLEAR_MODE=0
while getopts "a:b:C" opt; do
    case $opt in
        a) PREFIX=${OPTARG} ;;  # 计时前缀
        b) BATCH=${OPTARG} ;;   # 批次号
        C) CLEAR_MODE=1 ;;      # 启用清理模式
        *) echo "Usage: $0 -a <prefix> -b <batch> [-C]"
           exit 1 ;;
    esac
done
if [[ "$a" == "text" ]]; then
    echo "timer test successfully"
else
    # 检查清理模式
    if [[ $CLEAR_MODE -eq 1 ]]; then
        if [[ -z "$BATCH" ]]; then
            echo "Error: To clear a batch, you must specify -b <batch>."
            exit 1
        fi

        # 定义工作目录
        TIMER_BASE_DIR="${script_dir}/../temp"
        TIMER_WORK_DIR="${TIMER_BASE_DIR}/timer${BATCH}"

        if [[ -d "$TIMER_WORK_DIR" ]]; then
            rm -rf "$TIMER_WORK_DIR"
            echo "Batch ${BATCH} cleared successfully."
        else
            echo "Batch ${BATCH} does not exist. Nothing to clear."
        fi
        exit 0
    fi

    # 检查普通模式参数
    if [[ -z "$PREFIX" || -z "$BATCH" ]]; then
        echo "Error: Missing prefix or batch. Use -a to specify a prefix and -b to specify a batch."
        exit 1
    fi

    # 定义工作目录
    TIMER_BASE_DIR="${script_dir}/../temp"
    TIMER_WORK_DIR="${TIMER_BASE_DIR}/timer${BATCH}"

    # 如果工作目录不存在，则创建
    mkdir -p "${TIMER_WORK_DIR}"

    # 定义计时文件路径
    TIMER_FILE="${TIMER_WORK_DIR}/${PREFIX}_timer.txt"

    if [[ ! -f "$TIMER_FILE" ]]; then
        # 如果计时文件不存在，开始计时
        echo "Start timing for ${PREFIX}..."
        date +%s > "$TIMER_FILE"
    else
        # 如果计时文件存在，结束计时并计算时间差
        start_time=$(cat "$TIMER_FILE")
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "End timing for ${PREFIX}. Duration: ${duration} seconds."

        # 删除计时文件
        rm "$TIMER_FILE"
    fi
fi