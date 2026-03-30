#!/system/bin/sh

# 常量
LOG_FILE="${MODDIR:-/data/local/tmp}/sms_debug.log"
CONTENT_URI="content://sms/inbox"
POLL_INTERVAL=10
USER_ID=0

# 日志组件
log_info() {
    return 0
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# WxPusher 发送
wxpusher_send() {
    local content="$1"
    local appToken="appToken"
    local uids="uids"

    curl -s -X POST "https://wxpusher.zjiecode.com/api/send/message" \
        -H "Content-Type: application/json" \
        -d "{\"appToken\":\"${appToken}\",\"uids\":[\"${uids}\"],\"content\":\"${content}\",\"contentType\":2}"
}

# 解析短信行并返回 ID|ADDR|BODY|DATE
parse_sms_row() {
    local line="$1"
    log_info "解析短信行: $line"
    local id addr body date

    id=$(echo "$line" | sed -n 's/.*_id=\([^, ]*\).*/\1/p' | tr -cd '0-9')
    addr=$(echo "$line" | sed -n 's/.*address=\([^, ]*\).*/\1/p')
    body=$(echo "$line" | sed -n 's/.*body=\(.*\) date=.*/\1/p')
    body=$(echo "$body" | sed 's/[[:space:]]*,$//')
    date=$(echo "$line" | sed -n 's/.*date=\([^ ]*\).*/\1/p')

    if [ -n "$id" ]; then
        echo "$id|$addr|$body|$date"
        return 0
    fi
    echo ""
    return 1
}

# 读取最新一条短信（使用 Content Provider）
read_latest_sms() {
    local out parsed id address body date
    out=$(content query --uri "$CONTENT_URI" --user "$USER_ID" \
        --projection _id:address:body:date \
        --sort "date" 2>&1 | tr -d '\r')

    if echo "$out" | grep -q "Row:"; then
        parsed=$(echo "$out" | tail -n 1)
        parsed=$(parse_sms_row "$parsed")
        if [ -n "$parsed" ]; then
            echo "$parsed"
            return 0
        fi
    fi

    echo ""
    return 1
}

# 查询指定 ID 之后的新短信（增量）
read_new_sms_since() {
    local last_id="$1"
    content query --uri "$CONTENT_URI" --user "$USER_ID" \
        --projection _id:address:body:date \
        --where "_id>${last_id}" --sort "_id" 2>&1 | tr -d '\r'
}

# 启动时记录（清空日志）
: > "$LOG_FILE"
chmod 644 "$LOG_FILE"
log_info "脚本已启动，开始监听短信..."
log_info "短信内容来源: $CONTENT_URI"
log_info "轮询间隔: ${POLL_INTERVAL} 秒"
log_info "用户标识: ${USER_ID}"

# 初始化最新短信（首次成功读取仅初始化游标）
LAST_ID=0
LAST_DATE=0
INIT_DONE=0

# 轮询方式获取新短信
while true; do
    sleep "$POLL_INTERVAL"

    if [ "$INIT_DONE" -eq 0 ]; then
        LATEST=$(read_latest_sms)
        if [ -z "$LATEST" ]; then
            continue
        fi

        IFS='|' read -r NEW_ID NEW_ADDR NEW_BODY NEW_DATE <<EOF
$LATEST
EOF

        log_info "初始化游标: 当前=$NEW_ID 旧值=$LAST_ID"

        LAST_ID=$NEW_ID
        LAST_DATE=$NEW_DATE
        INIT_DONE=1
        log_info "初始化完成: ID=$LAST_ID 时间=$LAST_DATE"
        continue
    fi

    NEW_ROWS=$(read_new_sms_since "$LAST_ID")
    if ! echo "$NEW_ROWS" | grep -q "Row:"; then
        continue
    fi

    while read -r line; do
        case "$line" in
            Row:*)
                PARSED=$(parse_sms_row "$line")
                if [ -z "$PARSED" ]; then
                    continue
                fi

                IFS='|' read -r NEW_ID NEW_ADDR NEW_BODY NEW_DATE <<EOF
$PARSED
EOF

                if [ -n "$NEW_ID" ] && [ "$NEW_ID" -gt "$LAST_ID" ]; then
                    log_info "检测到新短信: 发件人=$NEW_ADDR 内容=$NEW_BODY"

                    wxpusher_send "<p>内容: ${NEW_BODY}</p><p>号码: ${NEW_ADDR}</p>"

                    LAST_ID=$NEW_ID
                    LAST_DATE=$NEW_DATE
                fi
                ;;
        esac
    done <<EOF
$NEW_ROWS
EOF
done
