#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Lỗi: Bạn cần chạy Script này dưới quyền root ( Không phải sudo ) !\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    LOGE "Phiên bản Linux không thể xác định, liên hệ dev！\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        LOGE "Bạn cần dùng thấp nhất bản CentOS 7 ！\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "Bạn cần dùng thấp nhất bản Ubuntu 16.04 ！\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "Bạn cần dùng thấp nhất bản Debian 8 ！\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Mặc định$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Có khởi động lại bảng điều khiển hay không, khởi động lại bảng điều khiển cũng sẽ khởi động lại xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn enter để quay lại menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/dopaemon/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "Chức năng này sẽ buộc cài đặt lại phiên bản mới nhất hiện tại, dữ liệu sẽ không bị mất, có tiếp tục không?" "n"
    if [[ $? != 0 ]]; then
        LOGE "Đã hủy"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/dopaemon/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "Cập nhật hoàn tất, bảng điều khiển đã được tự động khởi động lại "
        exit 0
    fi
}

uninstall() {
    confirm "Bạn có chắc chắn muốn gỡ cài đặt bảng điều khiển không, xray cũng sẽ gỡ cài đặt ?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "Gỡ cài đặt thành công, nếu bạn muốn xóa Script này, hãy nhập lệnh ${green}rm /usr/bin/x-ui -f${plain} sau khi thoát Script để hoàn tất gỡ X-UI"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Bạn có chắc chắn muốn đặt lại tên người dùng và mật khẩu cho admin không" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Tên người dùng và mật khẩu đã được đặt lại thành ${green}admin${plain}，Vui lòng khởi động lại bảng điều khiển ngay bây giờ"
    confirm_restart
}

reset_config() {
    confirm "Bạn có chắc chắn muốn đặt lại tất cả cài đặt bảng điều khiển, dữ liệu tài khoản sẽ không bị mất, tên người dùng và mật khẩu sẽ không bị thay đổi" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "Tất cả cài đặt bảng điều khiển đã được đặt lại về mặc định, vui lòng khởi động lại bảng điều khiển ngay bây giờ và sử dụng cài đặt mặc định ${green}54321${plain} Bảng điều khiển truy cập cổng"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "get current settings error,please check logs"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "Nhập Port [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Đã hủy"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "Sau khi thiết lập cổng, vui lòng khởi động lại bảng điều khiển và sử dụng Port mới đặt ${green}${port}${plain} bảng điều khiển truy cập"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "Bảng đã chạy rồi, không cần khởi động lại, nếu muốn khởi động lại, vui lòng chọn khởi động lại"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui Đã bắt đầu thành công"
        else
            LOGE "Bảng điều khiển không khởi động được, có thể do thời gian khởi động vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "Bảng điều khiển đã dừng, không cần dừng lại"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui và xray dừng thành công"
        else
            LOGE "Bảng điều khiển không dừng được, có thể do thời gian dừng vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký sau"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui và xray đã khởi động lại thành công"
    else
        LOGE "Bảng điều khiển không thể khởi động lại, có thể do thời gian khởi động vượt quá hai giây, vui lòng kiểm tra thông tin nhật ký sau"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui đặt khởi động thành công"
    else
        LOGE "x-ui không đặt được tự động khởi động khi khởi động"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui hủy khởi động tự khởi động thành công"
    else
        LOGE "x-ui không thể hủy chế độ tự khởi động"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/dopaemon/x-ui/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "Tập lệnh tải xuống không thành công, vui lòng kiểm tra xem máy có thể kết nối được không Github"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "Tập lệnh nâng cấp thành công, vui lòng chạy lại tập lệnh" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "Bảng điều khiển đã được cài đặt, vui lòng không cài đặt lại"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Vui lòng cài đặt bảng điều khiển trước"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "tình trạng bảng điều khiển: ${green}đã được chạy${plain}"
        show_enable_status
        ;;
    1)
        echo -e "tình trạng bảng điều khiển: ${yellow}không chạy${plain}"
        show_enable_status
        ;;
    2)
        echo -e "tình trạng bảng điều khiển: ${red}Chưa cài đặt${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Tự động bắt đầu không: ${green}Có${plain}"
    else
        echo -e "Tự động bắt đầu không: ${red}Không${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "Khởi chạy Xray: ${green}Khởi Chạy${plain}"
    else
        echo -e "Khởi chạy Xray: ${red}Không khởi chạy${plain}"
    fi
}

set_telegram_bot() {
    echo -E ""
    LOGI "Thiết lập Telegram Bot Cần Có Bot Token Và ChatId"
    confirm "Đồng Ý [y/n]" "y"
    if [ $? -ne 0 ]; then
        show_menu
    else
        read -p "please input your tg bot token here:" TG_BOT_TOKEN
        LOGI "Bot Token Của Bạn Thiết lập Là: $TG_BOT_TOKEN"
        read -p "please input your tg chat id here:" TG_BOT_CHATID
        LOGI "Chat ID Bạn Đã Đặt Là: $TG_BOT_CHATID"
	read -p "Nhập thời gian chạy bot Telegram\n - @ hourly - Chạy sau mỗi 1 giờ\n - 30 * * * * * - Chạy sau mỗi 30 phút\n - @ every 1h30m - Chạy sau mỗi 1 giờ 30 phút \nNhập thời gian bạn muốn bot chạy:" TG_BOT_RUNTIME
	LOGI "Thời gian chạy bot bạn đặt là: $TG_BOT_RUNTIME"
	info=$(/usr/local/x-ui/x-ui setting -tgbottoken ${TG_BOT_TOKEN} -tgbotchatid ${TG_BOT_CHATID} -tgbotRuntime "$TG_BOT_RUNTIME")
        if [ $? != 0 ]; then
            LOGE "$info"
            LOGE "Không Thể Thiết Lập Được Bot"
            exit 1
        else
            LOGI "Thiết Lập Bot Thành Công"
            show_menu
        fi
    fi
}

enable_telegram_bot() {
    echo -E ""
    LOGI "Kích Hoạt Thông Báo Bot Telegram"
    LOGI "Nội dung thông báo bao gồm: "
    LOGI "1.Lưu lượng sử dụng"
    LOGI "2.Nhắc hạn dùng server (Nếu có)"
    LOGI "3.Nhắc về việc đăng nhập dashboard (Cần Cập Nhật Thêm)"
    confirm "Đồng Ý Bật [y/n]" "y"
    if [ $? -eq 0 ]; then
        info=$(/usr/local/x-ui/x-ui setting -enabletgbot=true)
        if [ $? == 0 ]; then
            LOGI "Thành Công, Khởi động lại X-UI...."
            restart
        else
            LOGE "Thất bại, Ngưng..."
            exit 1
        fi
    else
        show_menu
    fi
}

disable_telegram_bot() {
    confirm "Bạn chắc muốn tắt Bot Telegram không? [y/n]" "n"
    if [ $? -eq 0 ]; then
        info=$(/usr/local/x-ui/x-ui setting -enabletgbot=false)
        if [ $? == 0 ]; then
            LOGI "Tắt thành công, khởi động lại X-UI để có hiệu lực...."
            restart
        else
            LOGE "Có lỗi xảy ra..."
            exit 1
        fi
    else
        show_menu
    fi
}


ssl_cert_issue() {
    echo -E ""
    LOGD "******Hướng dẫn sử dụng******"
    LOGI "Tập lệnh này sẽ sử dụng tập lệnh Acme để đăng ký chứng chỉ và bạn cần đảm bảo rằng nó được sử dụng:"
    LOGI "1.Biết email đã đăng ký Cloudflare"
    LOGI "2.Biết Cloudflare Global API Key"
    LOGI "3.Tên miền đã được giải quyết cho máy chủ hiện tại thông qua Cloudflare"
    LOGI "4.Đường dẫn cài đặt mặc định cho tập lệnh này để áp dụng cho chứng chỉ là /root/cert Nội dung"
    confirm "Tôi đã xác nhận ở trên [y/n]" "y"
    if [ $? -eq 0 ]; then
        cd ~
        LOGI "Cài đặt Acme Script"
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            LOGE "Không cài đặt được Script acme"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "Vui lòng đặt tên miền: "
        read -p "Nhập domain của bạn ở đây:" CF_Domain
        LOGD "Domain của bạn được đặt thành:${CF_Domain}"
        LOGD "Nhập API: "
        read -p "Nhập API key ở đây: " CF_GlobalKey
        LOGD "Khóa API của bạn là: ${CF_GlobalKey}"
        LOGD "Vui lòng đặt địa chỉ email đã đăng ký: "
        read -p "Nhập Email của bạn: " CF_AccountEmail
        LOGD "Email đã đăng ký của bạn là: ${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "Sửa đổi CA mặc định thành Lets'Encrypt không thành công và tập lệnh thoát"
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "Cấp chứng chỉ không thành công, tập lệnh thoát"
            exit 1
        else
            LOGI "Chứng chỉ được cấp thành công, quá trình cài đặt đang diễn ra..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "Cài đặt chứng chỉ không thành công, tập lệnh đã thoát"
            exit 1
        else
            LOGI "Chứng chỉ được cài đặt thành công, cho phép cập nhật tự động..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "Cài đặt cập nhật tự động không thành công, tập lệnh đã thoát"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "Chứng chỉ đã được cài đặt và cập nhật tự động đã được bật, thông tin chi tiết như sau"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

show_usage() {
    echo -e "x-ui Cách sử dụng tập lệnh quản lý: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Hiển thị menu quản lý (nhiều chức năng hơn)"
    echo -e "x-ui start        - Khởi động bảng điều khiển x-ui"
    echo -e "x-ui stop         - dừng bảng điều khiển x-ui"
    echo -e "x-ui restart      - khởi động lại bảng điều khiển x-ui"
    echo -e "x-ui status       - Xem trạng thái x-ui"
    echo -e "x-ui enable       - Đặt x-ui để bắt đầu tự động khi khởi động"
    echo -e "x-ui disable      - Hủy tự động khởi động x-ui boot"
    echo -e "x-ui log          - Xem nhật ký x-ui"
    echo -e "x-ui v2-ui        - Di chuyển dữ liệu tài khoản v2-ui của máy này sang x-ui"
    echo -e "x-ui update       - Cập nhật bảng điều khiển x-ui"
    echo -e "x-ui install      - cài đặt bảng điều khiển x-ui"
    echo -e "x-ui uninstall    - Gỡ cài đặt bảng điều khiển x-ui"
    echo -e "----------------------------------------------"
}

show_menu() {
    echo -e "
————————————————
██████╗  ██████╗ ██████╗  █████╗
██╔══██╗██╔═══██╗██╔══██╗██╔══██╗
██║  ██║██║   ██║██████╔╝███████║
██║  ██║██║   ██║██╔══██╗██╔══██║
██████╔╝╚██████╔╝██║  ██║██║  ██║
╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
https://github.com/dopaemon/x-ui.git
————————————————
  ${green}x-ui Tập lệnh quản lý bảng điều khiển${plain}
  ${green}0.${plain} Thoát Script
————————————————
  ${green}1.${plain} Cài đặt x-ui
  ${green}2.${plain} Cập Nhật x-ui
  ${green}3.${plain} Gỡ Cài Đặt x-ui
————————————————
  ${green}4.${plain} đặt lại mật khẩu tên người dùng
  ${green}5.${plain} đặt lại cài đặt bảng điều khiển
  ${green}6.${plain} Thiết lập các Port bảng điều khiển
  ${green}7.${plain} Cài đặt dashboard hiện tại
————————————————
  ${green}8.${plain} khởi động x-ui
  ${green}9.${plain} Ngừng x-ui
  ${green}10.${plain} khởi động lại x-ui
  ${green}11.${plain} Xem trạng thái x-ui
  ${green}12.${plain} Xem nhật ký x-ui
————————————————
  ${green}13.${plain} Đặt x-ui để bắt đầu tự động khi khởi động
  ${green}14.${plain} Hủy tự động khởi động x-ui boot
————————————————
  ${green}15.${plain} cài đặt bbr (hạt nhân mới nhất)
  ${green}16.${plain} Cài đặt chứng chỉ SSL (ứng dụng acme)
————————————————
  ${green}17.${plain} Bật Thông Báo Telegram Bot
  ${green}18.${plain} Tắt Thông Báo Telegram Bot
  ${green}19.${plain} Thiết lập Telegram Bot
 "
    show_status
    echo && read -p "Vui lòng nhập một lựa chọn [0-19]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    17)
        enable_telegram_bot
        ;;
    18)
        disable_telegram_bot
        ;;
    19)
        set_telegram_bot
        ;;
    *)
        LOGE "Vui lòng nhập lựa chọn [0-19]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
