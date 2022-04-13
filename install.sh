#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi：${plain} Bạn cần chạy tập lệnh này dưới user root ( không phải sudo ) ！\n" && exit 1

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
    echo -e "${red}Phiên bản Linux bạn đang dùng không thể xác định！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "x86" ]]; then
    arch="x86"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
elif [[ $arch == "riscv64" ]]; then
    arch="riscv64"
else
    arch="amd64"
    echo -e "${red}Không thể xác định cấu trúc CPU, thử dùng Kiến Trúc amd64 ${arch}${plain}"
fi

echo "Kiến Trúc CPU: ${arch}"

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
        echo -e "${red}Bạn dùng dùng phiên bản CentOS 7 hoặc mới hơn！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Bạn dùng dùng phiên bản Ubuntu 16.04 hoặc mới hơn！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Bạn dùng dùng phiên bản Debian 8 hoặc mới hơn！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}Vì lí do bảo mật, bạn nên đổi mật khẩu và tài khoản sau khi thiết lập xong ( hoặc cả port nếu bạn muốn )${plain}"
    read -p "Xác nhận cài đặt hoàn tất ？[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
    	read -p "Tài khoản: " config_account
    	echo -e "${yellow}Tên tài khoản bạn đặt là: ${config_account}${plain}"
    	read -p "Mật khẩu:" config_password
    	echo -e "${yellow}Mật khẩu của bạn đặt là: ${config_password}${plain}"
    	read -p "Nhập Port:" config_port
    	echo -e "${yellow}Port bạn sử dụng là: ${config_port}${plain}"
        echo -e "${yellow}Xác nhận cài đặt${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Hoàn tất đặt mật khẩu${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "\n${yellow}Hoàn tất đặt Port${plain}"
    else
        echo -e "${red}Đã hủy cài đặt: Vui lòng cài đặt X-UI lại hoặc gỡ cài đặt mặc định, lý do bảo mật.${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/dopaemon/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không thể xác định phiên bản X-UI, vui lòng kiểm tra github release hoặc API Github đã bị đổi${plain}"
            exit 1
        fi
        echo -e "Đã xác định bản Latest của X-UI：${last_version}，Bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/dopaemon/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không thể tải xuống X-UI, kiểm tra bộ nhớ, hoặc Internet${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/dopaemon/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Bắt đầu cài đặt x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không thể tải x-ui v$1，Đảm bảo rằng phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/dopaemon/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} Quá trình cài đặt hoàn tất, bảng điều khiển được khởi chạy，"
    echo -e ""
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

echo -e "${green}bắt đầu cài đặt${plain}"
install_base
install_x-ui $1
