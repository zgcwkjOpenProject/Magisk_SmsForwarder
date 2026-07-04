#!/system/bin/sh
# HTTP 服务 — 单端口 18080，同时处理静态文件和配置保存
# 空闲超时后自动退出，节省资源
MODDIR="/data/adb/modules/sms_forwarder"
PORT=18080
PID_FILE="/data/local/tmp/sms_forwarder_http.pid"
ACTIVITY_FILE="/data/local/tmp/sms_forwarder_activity"
WORKER="${MODDIR}/webroot/save_worker.sh"
IDLE_TIMEOUT=300  # 5 分钟无流量自动退出

echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT

# 查找 nc
NC=""
for p in /system/bin/nc nc toybox\ nc; do
    if [ -x "$p" ] || command -v $p > /dev/null 2>&1; then
        NC="$p"
        break
    fi
done

if [ -z "$NC" ]; then
    echo "错误: 找不到 nc"
    exit 1
fi

chmod +x "$WORKER" 2>/dev/null

echo "HTTP 服务启动: port=$PORT nc=$NC 超时=${IDLE_TIMEOUT}s"

# 主循环: 启动 nc → 启动看门狗 → 等待退出 → 检查活跃 → 重启或退出
while true; do
    date +%s > "$ACTIVITY_FILE"

    # 启动 nc -L 多连接模式
    $NC -L -p $PORT $WORKER 2>/dev/null &
    NC_PID=$!

    # 看门狗: 超时后杀掉 nc
    (sleep $IDLE_TIMEOUT; kill $NC_PID 2>/dev/null) &
    WATCH_PID=$!

    # 等待 nc 退出
    wait $NC_PID 2>/dev/null

    # 杀掉看门狗
    kill $WATCH_PID 2>/dev/null
    wait $WATCH_PID 2>/dev/null

    # 检查最后活跃时间
    if [ -f "$ACTIVITY_FILE" ]; then
        LAST=$(cat "$ACTIVITY_FILE" 2>/dev/null)
        NOW=$(date +%s)
        ELAPSED=$((NOW - LAST))
        if [ "$ELAPSED" -ge "$IDLE_TIMEOUT" ]; then
            echo "空闲 ${ELAPSED}s，服务自动退出"
            break
        fi
    fi

    sleep 1
done

rm -f "$PID_FILE" "$ACTIVITY_FILE"
