#!/bin/bash

export LANG=en_US.UTF-8

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora", "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Alpine")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install" "apk add -f")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove" "apk del -f")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "apk del -f")

[[ $EUID -ne 0 ]] && red "Phai chay duoi quyen root!" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "Hien tai X-UI khong ho tro cho OS cua ban, vui long su dung OS duoc ho tro" && exit 1

os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

[[ $SYSTEM == "CentOS" && ${os_version} -lt 7 ]] && echo -e "Phai chay tu phien ban CentOS 7 tro len!" && exit 1
[[ $SYSTEM == "Fedora" && ${os_version} -lt 29 ]] && echo -e "Phai chay tu phien ban Fedora 29 tro len!" && exit 1
[[ $SYSTEM == "Ubuntu" && ${os_version} -lt 16 ]] && echo -e "Phai chay tu phien ban Ubuntu 16 tro len!" && exit 1
[[ $SYSTEM == "Debian" && ${os_version} -lt 9 ]] && echo -e "Phai chay tu phien ban Debian 9 tro len!" && exit 1

archAffix(){
    case "$(uname -m)" in
        x86_64 | x64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "Khong ho tro kien truc CPU server cua ban!" && exit 1 ;;
    esac
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [default$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Co khoi dong lai X-UI hay khong, dieu nay dong thoi voi viec se khoi dong lai X-Ray luon do?" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${YELLOW}An phim Enter de tro lai man hinh chinh: ${PLAIN}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/quydang04/x-ui-vn/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    read -rp "Chuc nang nay se cap nhat X-UI len phien ban moi nhat, du lieu hien tai cua ban se khong bi mat, ban muon tiep tuc cap nhat chu? [Y/N]: " yn
    if [[ $yn =~ "Y"|"y" ]]; then
        systemctl stop x-ui
        if [[ -e /usr/local/x-ui/ ]]; then
            rm -rf /usr/local/x-ui/
        fi
        
        last_version=$(curl -Ls "https://api.github.com/repos/quydang04/x-ui-vn/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') || last_version=$(curl -sm8 https://raw.githubusercontent.com/quydang04/x-ui-vn/main/config/version)
        if [[ -z "$last_version" ]]; then
            red "Phat hien phien ban X-UI that bai, phai chac chan rang server cua ban da duoc ket noi den API cua Github"
            exit 1
        fi
        
        yellow "Phien ban moi nhat cua X-UI la: $ {last_version}, Bat dau cap nhat..."
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(archAffix).tar.gz https://github.com/quydang04/x-ui-vn/releases//download/${last_version}/x-ui-linux-$(archAffix).tar.gz
        if [[ $? -ne 0 ]]; then
            red "Tai cap nhat X-UI that bai, chac chan rang server cua ban da duoc ket noi mang roi chu??"
            exit 1
        fi
        
        cd /usr/local/
        tar zxvf x-ui-linux-$(archAffix).tar.gz
        rm -f x-ui-linux-$(archAffix).tar.gz
        
        cd x-ui
        chmod +x x-ui bin/xray-linux-$(archAffix)
        cp -f x-ui.service /etc/systemd/system/
        
        wget -N --no-check-certificate https://raw.githubusercontent.com/quydang04/x-ui-vn/main/x-ui.sh -O /usr/bin/x-ui
        chmod +x /usr/local/x-ui/x-ui.sh
        chmod +x /usr/bin/x-ui
        
        systemctl daemon-reload
        systemctl enable x-ui >/dev/null 2>&1
        systemctl start x-ui
        
        green "Qua trinh cai dat hoan tat, X-UI da duoc tu dong khoi dong lai"
        exit 1
    else
        red "Qua trinh cap nhat cua X-UI da bi huy"
        exit 1
    fi
}

uninstall() {
    confirm "Ban co muon go cai dat X-UI, dieu nay dong thoi ban  se go cai dat luon X-Ray do"
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
    rm /usr/bin/x-ui -f
    green "X-UI da duoc go cai dat, hi vong se gap lai ban ngay som nhat :( "
}

reset_user() {
    confirm "Ban co chac chan muon reset lai toan bo ten tai khoan va mat khau khong?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    read -rp "Dat ten tai khoan cua ban [mac dinh se duoc dat ngau nhien]: " config_account
    [[ -z $config_account ]] && config_account=$(date +%s%N | md5sum | cut -c 1-8)
    read -rp "Dat mat khau cho tai khoan [mac dinh se duoc dat ngau nhien]: " config_password
    [[ -z $config_password ]] && config_password=$(date +%s%N | md5sum | cut -c 1-8)
    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} >/dev/null 2>&1
    echo -e "Tai khoan dang nhap moi duoc dat lai la: ${GREEN} ${config_account} ${PLAIN}"
    echo -e "Mat khau dang nhap moi duoc dat lai la: ${GREEN} ${config_password} ${PLAIN}"
    green "Vui long su dung ten tai khoan va mat khau moi de dang nhap X-UI, ban phai ghi nho that ki chung do nha chua :)"
    confirm_restart
}

reset_config() {
    confirm "Ban co muon chac chan dat lai toan bo cai dat? Tat ca cac du lieu tai khoan se khong bi mat, tai khoan va mat khau se khong bi thay doi" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset >/dev/null 2>&1
    echo -e "Tat ca cac cai dat da duoc dat lai ve mac dinh, vui long truy cap lai X-UI theo port mac dinh $ {Green} 54321 $ {plain} "
    confirm_restart
}

set_port() {
    echo && echo -n -e "Nhap so cong port moi[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        red "Aborted!"
        before_show_menu
    else
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
                yellow "So cong port nay da duoc dat, vui long chon so cong port khac"
                echo -n -e "Nhap lai so cong port khac[1-65535]: " && read port
            fi
        done
        /usr/local/x-ui/x-ui setting -port ${port} >/dev/null 2>&1
        echo -e "Tat ca cac cai dat port da duoc cai dat lai , truy cap X-UI theo port moi$ {Green} $ {Port} $ {plain} de truy cap duoc bang dieu khien"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        green "X-UI da duoc chay, ban khong can phai khoi dong lai nua, neu ban muon thi hay an khoi dong lai X-UI"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            green "X-UI da duoc khoi dong"
        else
            red "Neu viec khoi dong X-UI that bai lien tuc, vui long mo log của X-UI de xem thong tin"
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
        green "X-UI da duoc dung, ban khong can phai dung nua"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            green "X-UI va X-Ray da duoc dung thanh cong"
        else
            red "Neu viec dung lai X-UI that bai lien tuc, vui long mo log của X-UI de xem thong tin"
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
        green "X-UI va X-Ray da duoc khoi dong thanh cong"
    else
        red "Neu viec khoi dong lai X-UI that bai lien tuc, vui long mo log của X-UI de xem thong tin"
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

enable_xui() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        green "X-UI se duoc tu khoi dong len sau khi he thong cua ban khoi dong"
    else
        red "Neu viec tu khoi dong X-UI that bai lien tuc, vui long mo log của X-UI de xem thong tin"
    fi
    
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable_xui() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        green "X-UI se duoc huy au khi he thong cua ban khoi dong"
    else
        red "Neu viec huy tu khoi dong X-UI that bai lien tuc, vui long mo log của X-UI de xem thong tin"
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
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/quydang04/x-ui-vn/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        red "Tai script that bai, chac chan rang server cua ban da duoc ket noi mang"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        green "Da cap nhat script thanh cong, vui long chay lai script de chap nhan su thay doi" && exit 1
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
        red "X-UI da duoc cai dat, vui long khong thuc hien lenh cai nua!!!"
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
        red "Vui long cai dat X-UI truoc"
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
            echo -e "Trang thai: ${GREEN}Dang chay${PLAIN}"
            show_enable_status
        ;;
        1)
            echo -e "Trang thai: ${YELLOW}Installed. Khong dang chay${PLAIN}"
            show_enable_status
        ;;
        2)
            echo -e "Trang thai: ${RED}Khong duoc cai dat${PLAIN}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether to start at your own boot: ${GREEN}Yes${PLAIN}"
    else
        echo -e "Whether to stop at your own boot: ${RED}no${PLAIN}"
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
        echo -e "Trang thai cua XRay: ${GREEN}Dang chay${PLAIN}"
    else
        echo -e "Trang thai cua XRay: ${RED}Khong dang chay${PLAIN}"
    fi
}

open_ports(){
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    green "Canh bao: Tat ca cac ket noi mang phai duoc mo!!!"
    before_show_menu
}

update_geo(){
    systemctl stop x-ui
    cd /usr/local/x-ui/bin
    rm -f geoip.dat geosite.dat
    wget -N https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
    wget -N https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    systemctl start x-ui
    green "Geosite and Geoip da duoc cap nhat thanh cong！"
}

check_login_info(){
    yellow "Cau hinh cua may chu va X-UI dang duoc kiem tra, vui long cho..."
    
    WgcfIPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WgcfIPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $WgcfIPv4Status =~ "on"|"plus" ]] || [[ $WgcfIPv6Status =~ "on"|"plus" ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        v6=$(curl -s6m8 https://ip.gs -k)
        v4=$(curl -s4m8 https://ip.gs -k)
        wg-quick up wgcf >/dev/null 2>&1
    else
        v6=$(curl -s6m8 https://ip.gs -k)
        v4=$(curl -s4m8 https://ip.gs -k)
    fi
    
    config_port=$(/usr/local/x-ui/x-ui 2>&1 | grep tcp | awk '{print $5}' | sed "s/://g")
}

show_usage() {
    green "X-UI Vietnamese v${last_version} da duoc cai dat hoan tat, bang dieu khien da duoc khoi dong"
    echo -e ""
    echo -e "${GREEN} --------------------------------------------------------------------- ${PLAIN}"
    echo -e "X-UI Vietnamese Translation"
    echo -e "------------------------------------------------------------------------------"
    echo -e "Cac lenh cua X-UI "
    echo -e "------------------------------------------------------------------------------"
    echo -e "x-ui              - Hien thi menu quan ly"
    echo -e "x-ui start        - Khoi dong X-UI"
    echo -e "x-ui stop         - Dung X-UI"
    echo -e "x-ui restart      - Khoi dong lai X-UI"
    echo -e "x-ui status       - Xem trang thai cua X-UI"
    echo -e "x-ui enable       - Bat X-UI khoi dong cung he thong"
    echo -e "x-ui disable      - Tat X-UI khoi dong cung he thong"
    echo -e "x-ui log          - Xem log cua X-UI"
    echo -e "x-ui v2-ui        - Di chuyen tu V2-UI sang X-UI"
    echo -e "x-ui update       - Cap nhat X-UI"
    echo -e "x-ui install      - Cai dat X-UI"
    echo -e "x-ui uninstall    - Go cai dat X-UI"
    echo -e "------------------------------------------------------------------------------"
    echo -e ""
}

show_menu() {
    echo -e "
--------------------------------------------------------------------------------
  ${GREEN}X-UI VIETNAMESE PANEL MANAGEMENT SCRIPT ${PLAIN}
--------------------------------------------------------------------------------
  ${GREEN}0.${PLAIN} Thoat Script
--------------------------------------------------------------------------------
  ${GREEN}1.${PLAIN} Cai dat X-UI
  ${GREEN}2.${PLAIN} Cap nhat X-UI
  ${GREEN}3.${PLAIN} Go cai dat X-UI
--------------------------------------------------------------------------------
  ${GREEN}4.${PLAIN} Dat lai mat khau cho tai khoan
  ${GREEN}5.${PLAIN} Dat lai cai dat bang dieu khien
  ${GREEN}6.${PLAIN} Dat lai cong port cho bang dieu khien
--------------------------------------------------------------------------------
  ${GREEN}7.${PLAIN} Khoi dong X-UI
  ${GREEN}8.${PLAIN} Dung X-UI
  ${GREEN}9.${PLAIN} Khoi dong lai X-UI
 ${GREEN}10.${PLAIN} Kiem tra trang thai cua X-UI
 ${GREEN}11.${PLAIN} Xem log cua X-UI
---------------------------------------------------------------------------------
 ${GREEN}12.${PLAIN} Cho phep X-UI khoi dong cung he thong
 ${GREEN}13.${PLAIN} Khong cho phep X-UI khoi dong cung he thong
---------------------------------------------------------------------------------
 ${GREEN}14.${PLAIN} Cap Geosite and Geoip
 ${GREEN}15.${PLAIN} One-click installation BBR (the latest kernel)
 ${GREEN}16.${PLAIN} One-click application certificate (ACME script application)
 ${GREEN}17.${PLAIN} Mo tat ca cac cong ket noi mang cua may chu
 ${GREEN}18.${PLAIN} Cai dat va cau hinh Cloudflare Wrap (Experimental)
 --------------------------------------------------------------------------------   "
    show_status
    echo ""
    if [[ -n $v4 && -z $v6 ]]; then
        echo -e "Dia chi login IPV4: ${GREEN}http://$v4:$config_port ${PLAIN}"
    elif [[ -n $v6 && -z $v4 ]]; then
        echo -e "Dia chi login IPV6: ${GREEN}http://[$v6]:$config_port ${PLAIN}"
    elif [[ -n $v4 && -n $v6 ]]; then
        echo -e "Dia chi login bang dieu khien IPV4: ${GREEN}http://$v4:$config_port ${PLAIN}"
        echo -e "Dia chi login bang dieu khien IPV4: ${GREEN}http://[$v6]:$config_port ${PLAIN}"
    fi
    echo && read -rp "Vui long chon so cai dat [0-18]: " num
    
    case "${num}" in
        0) exit 1 ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && reset_user ;;
        5) check_install && reset_config ;;
        6) check_install && set_port ;;
        7) check_install && start ;;
        8) check_install && stop ;;
        9) check_install && restart ;;
        10) check_install && status ;;
        11) check_install && show_log ;;
        12) check_install && enable_xui ;;
        13) check_install && disable_xui ;;
        14) update_geo ;;
        15) install_bbr ;;
        16) wget -N --no-check-certificate https://raw.githubusercontent.com/NidukaAkalanka/x-ui-english/main/acme.sh && bash acme.sh && before_show_menu ;;
        17) open_ports ;;
        18) wget -N --no-check-certificate https://raw.githubusercontent.com/taffychan/warp/main/warp.sh && bash warp.sh && before_show_menu ;;
        *) red "Phai chon dung so cai dat tu [0-18]" ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable_xui 0 ;;
        "disable") check_install 0 && disable_xui 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "v2-ui") check_install 0 && migrate_v2_ui 0 ;;
        "update") check_install 0 && update ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        *) show_usage ;;
    esac
else
    check_login_info && show_menu
fi
