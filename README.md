# Move to this repo: [https://github.com/X-UI-Unofficial](https://github.com/X-UI-Unofficial)

<h1 align="center">X-UI Unofficial.</h1>

> Đây Là Phiên Bản X-UI được Việt Hoá và cập nhật Xray định kỳ. kèm các bản vá Pull.

# Đọc kỹ rồi làm gì hẳng làm. Làm ơn. Install Lộn Script Không Được Ráng Chịu.

## Support Platform
Linux:
```
Debian
Ubuntu
CentOS
RaspberryPI OS
Armbian
```
Arch:
```
amd64
arm64
s390x
```
## Cài Đặt Bằng Tay
- Đọc kỹ rồi làm gì hẳng làm
```
# Thay đổi theo danh sách Arch phía trên, Cho đúng thiết bị của bạn.
export UARCH="arm64"
```
- Tải bản X-UI theo Cấu trúc CPU bạn dùng tại đây [Release](https://github.com/dopaemon/x-ui/releases)
```
sudo -s
```
```
rm x-ui/ /usr/local/x-ui/ /usr/bin/x-ui -rf
```
```
tar zxvf x-ui-linux-$UARCH.tar.gz
```
```
chmod +x x-ui/x-ui x-ui/bin/xray-linux-* x-ui/x-ui.sh
```
```
cp x-ui/x-ui.sh /usr/bin/x-ui
```
```
cp -f x-ui/x-ui.service /etc/systemd/system/
```
```
mv x-ui/ /usr/local/
```
```
systemctl daemon-reload
```
```
systemctl enable x-ui
```
```
systemctl restart x-ui
```
```
Tài khoản mặc định:
- TK: admin
- PW: admin
- PR: 54321
```
## Cài Đặt Bằng Script [ Đọc lưu ý phía dưới ]
## Chỉ Support: amd64, arm64, s390x.
```
Tắt Unikey trước khi chạy Script. Tránh trình trạng Sai Mật Khẩu
```
## Theme Sofbox [ Stable ]
[Demo Theme](https://dopaemon.github.io/-Sofbox-Admin-Template/index.html)
```
sudo -s
```
```
bash <(curl -Ls https://raw.githubusercontent.com/dopaemon/x-ui/main/install.sh)
```
## Theme SBAdmin 2 [ Stable ]
[Demo Theme](https://startbootstrap.github.io/startbootstrap-sb-admin-2/)
- Nếu bạn có 1 bản Linux đã cũ: GLIBC_2.28 not found
```
sudo -s
```
```
bash <(curl -Ls https://raw.githubusercontent.com/dopaemon/x-ui/main/install.sh) 0.3.4.4-SBAdmin
```
## Cài đặt bản Latest [ Có thể không ổn định ]
```
sudo -s
```
```
bash <(curl -Ls https://raw.githubusercontent.com/dopaemon/x-ui/main/install.sh) Dev
```
## ⚠️⚠️⚠️ Làm ơn không dùng cách này để install x-ui
```
sudo bash <(curl -Ls https://raw.githubusercontent.com/dopaemon/x-ui/main/install.sh)
```
## Owner: Dự án gốc nằm ở đây [**vaxilu**](https://github.com/vaxilu/x-ui) - Tôi chỉ phát triển nó cho người Việt Nam dễ tiếp cận hơn.
