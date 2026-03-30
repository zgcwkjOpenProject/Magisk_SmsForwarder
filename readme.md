# SmsForwarder

短信转发模块，使用 WxPusher 推送

## 使用说明

> 因为不会搞可视化页面，所以手动操作吧

1. 创建接收消息：https://wxpusher.zjiecode.com/admin/main/wxuser/list
2. 将 ``src`` 目录下的文件压缩成 zip 格式，然后将压缩的文件放到手机
3. 安装模块选刚刚压缩的文件，安装完成后不要重启手机，打开 ``/data/adb/modules/sms_forwarder/sms_forward.sh`` 修改 appToken 和 uids 值
4. 重启手机即可使用

## 图片预览

![20260329170742.jpg](imgs/20260329170742.jpg)
