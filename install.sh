#!/bin/bash

export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

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

[[ $EUID -ne 0 ]] && red "Phai chay duoi quyen root！" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "Hien tai X-UI khong ho tro cho OS cua ban, vui long su dung OS duoc ho tro" && exit 1

cur_dir=$(pwd)
os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

[[ $SYSTEM == "CentOS" && ${os_version} -lt 7 ]] && echo -e "Vui long su dung tu CentOS 7 tro len" && exit 1
[[ $SYSTEM == "Fedora" && ${os_version} -lt 29 ]] && echo -e "Vui long su dung tu Fedora 29 tro len" && exit 1
[[ $SYSTEM == "Ubuntu" && ${os_version} -lt 16 ]] && echo -e "Vui long su dung tu Ubuntu 16 tro len" && exit 1
[[ $SYSTEM == "Debian" && ${os_version} -lt 9 ]] && echo -e "Vui long su dung tu Debian 9 tro len" && exit 1

archAffix(){
    case "$(uname -m)" in
        x86_64 | x64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "Khong ho tro cho kien truc CPU server cua ban " && rm -f install.sh && exit 1 ;;
    esac
}

info_bar(){
    clear
    echo -e "${GREEN} --------------------------------------------------------------------- ${PLAIN}"
    echo "X-UI Vietnamese Version"
    echo -e "${GREEN} --------------------------------------------------------------------- ${PLAIN}"
    echo -e "Phai hien duoc OS: ${GREEN} ${CMD} ${PLAIN}"
    echo ""
    echo -e "${GREEN} --------------------------------------------------------------------- ${PLAIN}"
    sleep 2
}

check_status(){
    yellow "Dang kiem tra moi truong cau hình IP cua may chu, vui long cho..." && sleep 1
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
        if [[ -z $v4 && -n $v6 ]]; then
            yellow "Chỉ IPv6 được phát hiện. Vì vậy, máy chủ phân tích cú pháp DNS64 đã được thêm tự động"
            echo -e "nameserver 2606:4700:4700::1111" > /etc/resolv.conf
        fi
    fi
    sleep 1
}

install_base(){
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    if [[ -z $(type -P curl) ]]; then
        ${PACKAGE_INSTALL[int]} curl
    fi
    if [[ -z $(type -P tar) ]]; then
        ${PACKAGE_INSTALL[int]} tar
    fi   
    check_status
}

download_xui(){
    if [[ -e /usr/local/x-ui/ ]]; then
        rm -rf /usr/local/x-ui/
    fi
    
    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/quydang04/x-ui-vn/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') || last_version=$(curl -sm8 https://raw.githubusercontent.com/quydang04/x-ui-vn/main/config/version >/dev/null 2>&1)
        if [[ -z "$last_version" ]]; then
            red "Phat hien phien ban X-UI that bai, phai chac chan rang server cua ban phai duoc ket noi den API cua Github"
            rm -f install.sh
            exit 1
        fi
        yellow "Phat hien duoc phien ban mơi nhat cua X-UI $ {last_version}, bat dau qua trinh cai dat..."
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(archAffix).tar.gz https://github.com/quydang04/x-ui-vn/releases/download/${last_version}/x-ui-linux-$(archAffix).tar.gz
        if [[ $? -ne 0 ]]; then
            red "Tai X-UI that bai, phai chac chan rang server cua ban da duoc ket noi mang"
            rm -f install.sh
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/quydang04/x-ui-vn/releases/download/${last_version}/x-ui-linux-$(archAffix).tar.gz"
        yellow "Bat dau cai dat X-UI $1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(archAffix).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            red "Tai ve phien ban X-UI $ 1 that bai, phai chac chan rang phien ban nay da ton tai hay chua?"
            rm -f install.sh
            exit 1
        fi
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
}

panel_config() {
    yellow "Vi ly do bao mat, sau khi qua trinh cai dat/ cap nhat, ban phai ghi nho lai tai khoan, mat khau va so cong port cua X-UI"
    read -rp "Dat ten tai khoan cua ban [mac dinh se duoc dat ngau nhien]: " config_account
    [[ -z $config_account ]] && config_account=$(date +%s%N | md5sum | cut -c 1-8)
    read -rp "Dat mat khau cho tai khoan [mac dinh se duoc dat ngau nhien]: " config_password
    [[ -z $config_password ]] && config_password=$(date +%s%N | md5sum | cut -c 1-8)
    read -rp "Nhap so cong port ma ban muon dat [mac dinh se duoc dat ngau nhien]: " config_port
    [[ -z $config_port ]] && config_port=$(shuf -i 1000-65535 -n 1)
    until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$config_port") ]]; do
        if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w  "$config_port") ]]; then
            yellow "So cong port nay da duoc dat, vui long chon so cong port khac"
            read -rp "Nhap so cong port ma ban muon dat [mac dinh se duoc dat ngau nhien]: " config_port
            [[ -z $config_port ]] && config_port=$(shuf -i 1000-65535 -n 1)
        fi
    done
    /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password} >/dev/null 2>&1
    /usr/local/x-ui/x-ui setting -port ${config_port} >/dev/null 2>&1
}

install_xui() {
    info_bar
    
    if [[ -e /usr/local/x-ui/ ]]; then
        yellow "X-UI hien da duoc cai dat, ban co chac chan muon xoa no chu?"
        read -rp "Vui long chon [y/n, default n]: " yn
        if [[ $yn =~ "Y"|"y" ]]; then
            systemctl stop x-ui
            systemctl disable x-ui
            rm /etc/systemd/system/x-ui.service -f
            systemctl daemon-reload
            systemctl reset-failed
            rm /etc/x-ui/ -rf
            rm /usr/local/x-ui/ -rf
            rm /usr/bin/x-ui -f
        else
            red "Da huy va go cai dat!"
            exit 1
        fi
    fi
    
    systemctl stop x-ui >/dev/null 2>&1
    
    install_base
    download_xui $1
    panel_config
    
    systemctl daemon-reload
    systemctl enable x-ui >/dev/null 2>&1
    systemctl start x-ui
    
    cd $cur_dir
    rm -f install.sh
    green "X-UI v${last_version} Qua trinh cai dat hoan tat, X-UI da duoc khoi dong va dang chay!"
    echo -e ""
    echo -e "------------------------------------------------------------------------------"
    echo -e "CAC LENH CUA X-UI "
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
    echo -e "------------------------------------------------------------------------------"
    echo -e "Please do consider supporting authors"
    echo -e "------------------------------------------------------------------------------"
    echo -e "vaxilu            - https://github.com/vaxilu" 
    echo -e "taffychan         - https://github.com/taffychan"  
    echo -e "LuckyHunter       - https://github.com/Chasing66"
    echo -e "Yu FranzKafka     - https://github.com/FranzKafkaYu"
    echo -e "Niduka Akalanka   - https://github.com/NidukaAkalanka"
    echo -e "--------------------------------------------------------------------------------"
     echo -e "X-UI Vietnamese translation author:" 
   echo -e "--------------------------------------------------------------------------------"
    echo -e "quydang            - https://github.com/quydang04" 
     echo -e "--------------------------------------------------------------------------------"
    show_login_info
    echo -e ""
    yellow "(Neu ban khong truy cap duoc X-UI, dieu dau tien hay go vao SSH lenh so 17, sau do cau hinh lai cong port cua ban!)"
}

show_login_info(){
    if [[ -n $v4 && -z $v6 ]]; then
        echo -e "Dia chi login IPV4: ${GREEN}http://$v4:$config_port ${PLAIN}"
    elif [[ -n $v6 && -z $v4 ]]; then
        echo -e "Dia chi login IPV6: ${GREEN}http://[$v6]:$config_port ${PLAIN}"
    elif [[ -n $v4 && -n $v6 ]]; then
        echo -e "Dia chi login IPV4: ${GREEN}http://$v4:$config_port ${PLAIN}"
        echo -e "Dia chi login IPV6: ${GREEN}http://[$v6]:$config_port ${PLAIN}"
    fi
    echo -e "Ten tai khoan: ${GREEN}$config_account ${PLAIN}"
    echo -e "Mat khau: ${GREEN}$config_password ${PLAIN}"
}

install_xui $1
