#!/system/bin/sh
MODDIR=${0%/*}
PID_FILE="/data/local/tmp/sms_forwarder_http.pid"

# 确保配置文件存在
if [ ! -f "${MODDIR}/sms_config.sh" ]; then
    echo 'userId=0' >> "${MODDIR}/sms_config.sh"
    echo 'appToken="appToken"' > "${MODDIR}/sms_config.sh"
    echo 'uids="uids"' >> "${MODDIR}/sms_config.sh"
fi

# WebUI 访问配置的 symlink
WEBUI_LINK="${MODDIR}/webroot/sms_config.sh"
if [ ! -L "$WEBUI_LINK" ]; then
    [ -f "$WEBUI_LINK" ] && mv "$WEBUI_LINK" "${WEBUI_LINK}.bak" 2>/dev/null
    ln -sf "${MODDIR}/sms_config.sh" "$WEBUI_LINK" 2>/dev/null
fi

# 启动 HTTP 服务 (nc -L 单端口，同时处理静态文件和保存)
chmod +x "${MODDIR}/webroot/save.sh" 2>/dev/null
chmod +x "${MODDIR}/webroot/save_worker.sh" 2>/dev/null
NEED_START=1
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        NEED_START=0
    fi
fi
if [ "$NEED_START" -eq 1 ]; then
    rm -f "$PID_FILE"
    /system/bin/sh "${MODDIR}/webroot/save.sh" > /dev/null 2>&1 &
fi

# 启动短信转发守护进程
chmod +x $MODDIR/sms_forward.sh

# 在后台挂起守护进程，将输出重定向以避免阻塞系统启动
export MODDIR
nohup /system/bin/sh $MODDIR/sms_forward.sh > /dev/null 2>&1 &
