#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_FILE="${MODDIR}/sms_config.sh"

# 读取当前配置
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

echo "========================================"
echo "  SMS Forwarder - 配置工具"
echo "========================================"
echo ""
echo "[当前配置]"
echo "  appToken: ${appToken:-(未设置)}"
echo "  uids:     ${uids:-(未设置)}"
echo ""

# 启动 HTTP 服务
chmod +x "${MODDIR}/webroot/save.sh" 2>/dev/null
chmod +x "${MODDIR}/webroot/save_worker.sh" 2>/dev/null
PID_FILE="/data/local/tmp/sms_forwarder_http.pid"
NEED_START=1
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        NEED_START=0
    fi
fi
if [ "$NEED_START" -eq 1 ]; then
    echo "[启动 Web 服务...]"
    rm -f "$PID_FILE"
    /system/bin/sh "${MODDIR}/webroot/save.sh" > /dev/null 2>&1 &
    sleep 1
fi

# 打开浏览器（后台异步执行，不阻塞脚本）
URL="http://localhost:18080"
nohup /system/bin/am start -a android.intent.action.VIEW -d "$URL" > /dev/null 2>&1 &

echo ""
echo "  已打开管理页面: $URL"
echo "  配置文件: $CONFIG_FILE"
echo "  空闲 5 分钟后服务自动退出"
echo "========================================"
