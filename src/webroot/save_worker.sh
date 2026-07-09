#!/system/bin/sh
# HTTP worker — 每个连接由 nc 调用，处理静态文件和配置保存
MODDIR="/data/adb/modules/sms_forwarder"
WEBROOT="${MODDIR}/webroot"
CONFIG_FILE="${MODDIR}/sms_config.sh"
ACTIVITY_FILE="/data/local/tmp/sms_forwarder_activity"
CONFIG_CHANGED_FLAG="/data/local/tmp/sms_forwarder_config_changed"

# 更新活跃时间
date +%s > "$ACTIVITY_FILE" 2>/dev/null

# 读取 HTTP 请求行
read -r REQUEST_LINE
REQUEST_LINE=$(printf '%s' "$REQUEST_LINE" | tr -d '\r')

# 读取并丢弃 headers
while read -r LINE; do
    LINE=$(printf '%s' "$LINE" | tr -d '\r')
    [ -z "$LINE" ] && break
done

# 解析: METHOD PATH PROTO
METHOD=$(printf '%s' "$REQUEST_LINE" | awk '{print $1}')
URL_PATH=$(printf '%s' "$REQUEST_LINE" | awk '{print $2}')

# 分离路径和 query string
FILE_PATH="${URL_PATH%%\?*}"
QS="${URL_PATH#*\?}"
[ "$FILE_PATH" = "$QS" ] && QS=""

# 默认首页
[ -z "$FILE_PATH" ] || [ "$FILE_PATH" = "/" ] && FILE_PATH="/index.html"

# --- 处理保存请求 ---
if [ "$FILE_PATH" = "/save.sh" ]; then
    userId="0"
    appToken=""
    uids=""
    if [ -n "$QS" ]; then
        userId=$(printf '%s' "$QS" | sed 's/.*userId=\([^&]*\).*/\1/')
        appToken=$(printf '%s' "$QS" | sed 's/.*appToken=\([^&]*\).*/\1/')
        uids=$(printf '%s' "$QS" | sed 's/.*uids=\([^&]*\).*/\1/')
    fi
    [ -z "$userId" ] && userId="0"
    if [ -n "$appToken" ] && [ -n "$uids" ]; then
        printf '# SMS Forwarder 配置文件\nuserId=%s\nappToken="%s"\nuids="%s"\n' "$userId" "$appToken" "$uids" > "$CONFIG_FILE"
        # 创建配置变更标识文件
        touch "$CONFIG_CHANGED_FLAG"
        # 重启短信转发进程使配置立即生效
        pkill -f sms_forward.sh 2>/dev/null
        MODDIR="${CONFIG_FILE%/*}"
        export MODDIR
        nohup /system/bin/sh "${MODDIR}/sms_forward.sh" > /dev/null 2>&1 &
        BODY="OK"
    else
        BODY="ERROR"
    fi
    printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" "${#BODY}" "$BODY"
    exit 0
fi

# --- 处理 CORS 预检 ---
if [ "$METHOD" = "OPTIONS" ]; then
    printf "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET\r\nConnection: close\r\n\r\n"
    exit 0
fi

# --- 处理静态文件 ---
REAL_PATH="${WEBROOT}${FILE_PATH}"

# 安全检查: 防止路径穿越
case "$FILE_PATH" in
    *..*) printf "HTTP/1.1 403 Forbidden\r\nContent-Length: 13\r\nConnection: close\r\n\r\n403 Forbidden"; exit 0 ;;
esac

if [ ! -f "$REAL_PATH" ]; then
    BODY="404 Not Found"
    printf "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" "${#BODY}" "$BODY"
    exit 0
fi

# 判断 Content-Type
case "$FILE_PATH" in
    *.html)                CT="text/html; charset=utf-8" ;;
    *.json)                CT="application/json" ;;
    *.css)                 CT="text/css" ;;
    *.js)                  CT="application/javascript" ;;
    *.png)                 CT="image/png" ;;
    *.jpg|*.jpeg)          CT="image/jpeg" ;;
    *.gif)                 CT="image/gif" ;;
    *.svg)                 CT="image/svg+xml" ;;
    *.ico)                 CT="image/x-icon" ;;
    *.sh|*.conf|*.config)  CT="text/plain" ;;
    *)                     CT="application/octet-stream" ;;
esac

FSIZE=$(wc -c < "$REAL_PATH" | tr -d ' ')

printf "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %s\r\nConnection: close\r\n\r\n" "$CT" "$FSIZE"
cat "$REAL_PATH"
