package job

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"time"
	"x-ui/logger"
	"x-ui/util/common"
	"x-ui/web/service"
)

var SSHLoginUser int

type LoginStatus byte

const (
	LoginSuccess LoginStatus = 1
	LoginFail    LoginStatus = 0
)

type StatsNotifyJob struct {
	enable          bool
	telegramService service.TelegramService
	xrayService     service.XrayService
	inboundService  service.InboundService
	settingService  service.SettingService
}

func NewStatsNotifyJob() *StatsNotifyJob {
	return new(StatsNotifyJob)
}

//Here run is a interface method of Job interface
func (j *StatsNotifyJob) Run() {
	if !j.xrayService.IsXrayRunning() {
		return
	}
	var info string
	info = j.GetsystemStatus()
	j.telegramService.SendMsgToTgbot(info)
}

func (j *StatsNotifyJob) UserLoginNotify(username string, ip string, time string, status LoginStatus) {
	if username == "" || ip == "" || time == "" {
		logger.Warning("Thông báo đăng nhập người dùng không thành công, thông tin không hợp lệ")
		return
	}
	var msg string
	//get hostname
	name, err := os.Hostname()
	if err != nil {
		fmt.Println("Nhận tên máy chủ lỗi: ", err)
		return
	}
	if status == LoginSuccess {
		msg = fmt.Sprintf("Nhắc nhở đăng nhập thành công bảng điều khiển\r\nTên máy chủ: %s\r\n", name)
	} else if status == LoginFail {
		msg = fmt.Sprintf("Nhắc nhở đăng nhập không thành công bảng điều khiển\r\nTên máy chủ: %s\r\n", name)
	}
	msg += fmt.Sprintf("Time: %s\r\n", time)
	msg += fmt.Sprintf("User: %s\r\n", username)
	msg += fmt.Sprintf("IP: %s\r\n", ip)
	j.telegramService.SendMsgToTgbot(msg)
}

func (j *StatsNotifyJob) SSHStatusLoginNotify(xuiStartTime string) {
	getSSHUserNumber, error := exec.Command("bash", "-c", "who | awk  '{print $1}' | wc -l").Output()
	if error != nil {
		fmt.Println("gặp lỗi số người dùng SSH: ", error)
		return
	}
	var numberInt int
	numberInt, error = strconv.Atoi(common.ByteToString(getSSHUserNumber))
	if error != nil {
		return
	}
	if numberInt > SSHLoginUser {
		var SSHLoginInfo string
		SSHLoginUser = numberInt
		//hostname
		name, err := os.Hostname()
		if err != nil {
			fmt.Println("Nhận tên máy chủ lỗi: ", err)
			return
		}
		//Time compare,need if x-ui got restart while ssh already exist users
		SSHLoginTime, error := exec.Command("bash", "-c", "who | awk  '{print $3,$4}' | tail -n 1 ").Output()
		if error != nil {
			fmt.Println("Nhận thời gian đăng nhập lỗi: ", error.Error())
			return
		}
		var SSHLoginTimeStr string
		SSHLoginTimeStr = common.ByteToString(SSHLoginTime)
		t1, err := time.Parse("2006-01-02 15:04:05", SSHLoginTimeStr)
		t2, err := time.Parse("2006-01-02 15:04:05", xuiStartTime)
		if t1.Before(t2) || err != nil {
			fmt.Printf("SSHLogin[%s] early than XUI start[%s]\r\n", SSHLoginTimeStr, xuiStartTime)
		}

		SSHLoginUserName, error := exec.Command("bash", "-c", "who | awk  '{print $1}'| tail -n 1").Output()
		if error != nil {
			fmt.Println("Lấy tên đăng nhập SSH lỗi: ", error.Error())
			return
		}

		SSHLoginIpAddr, error := exec.Command("bash", "-c", "who | tail -n 1 | awk -F [\\(\\)] 'NR==1 {print $2}'").Output()
		if error != nil {
			fmt.Println("Lấy địa chỉ đăng nhập SSH lỗi: ", error)
			return
		}

		SSHLoginInfo = fmt.Sprintf(" SSH user login reminder:\r\n")
		SSHLoginInfo += fmt.Sprintf("Host name: %s\r\n", name)
		SSHLoginInfo += fmt.Sprintf("Login user: %s", SSHLoginUserName)
		SSHLoginInfo += fmt.Sprintf("Log in time: %s", SSHLoginTime)
		SSHLoginInfo += fmt.Sprintf("Login IP: %s", SSHLoginIpAddr)
		SSHLoginInfo += fmt.Sprintf("Hiện đang đăng nhập số lượng người dùng: %s", getSSHUserNumber)
		j.telegramService.SendMsgToTgbot(SSHLoginInfo)
	} else {
		SSHLoginUser = numberInt
	}
}

func (j *StatsNotifyJob) GetsystemStatus() string {
	var info string
	//get hostname
	name, err := os.Hostname()
	if err != nil {
		fmt.Println("Lấy thông tin máy chủ lỗi:", err)
		return ""
	}
	info = fmt.Sprintf("Tên máy chủ: %s\r\n", name)
	//get ip address
	var ip string
	ip = common.GetMyIpAddr()
	info += fmt.Sprintf("Địa chỉ IP: %s\r\n \r\n", ip)

	//get traffic
	inbouds, err := j.inboundService.GetAllInbounds()
	if err != nil {
		logger.Warning("StatsNotifyJob run failed: ", err)
		return ""
	}
	//NOTE:If there no any sessions here,need to notify here
	//TODO:Sub -node push, automatic conversion format
	for _, inbound := range inbouds {
		info += fmt.Sprintf("Tên node: %s\r\n Cổng: %d\r\n Lượng tải lên ↑: %s\r\n Lượng tải xuống ↓: %s\r\n Tổng lưu lượng: %s\r\n", inbound.Remark, inbound.Port, common.FormatTraffic(inbound.Up), common.FormatTraffic(inbound.Down), common.FormatTraffic((inbound.Up + inbound.Down)))
		if inbound.ExpiryTime == 0 {
			info += fmt.Sprintf("Understanding time: indefinitely\r\n \r\n")
		} else {
			info += fmt.Sprintf("Ngày hết hạn: %s\r\n \r\n", time.Unix((inbound.ExpiryTime/1000), 0).Format("2006-01-02 15:04:05"))
		}
	}
	return info
}
