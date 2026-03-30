#!/system/bin/sh
MODDIR=${0%/*}

# 给执行脚本赋予权限
chmod +x $MODDIR/sms_forward.sh

# 在后台挂起守护进程，将输出重定向以避免阻塞系统启动
export MODDIR
nohup /system/bin/sh $MODDIR/sms_forward.sh > /dev/null 2>&1 &
