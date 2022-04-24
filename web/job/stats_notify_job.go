package job

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"strconv"
	"time"
	"x-ui/logger"
	"x-ui/util/common"
	"x-ui/web/service"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
)

var SSHLoginUser int

type LoginStatus byte

const (
	LoginSuccess LoginStatus = 1
	LoginFail    LoginStatus = 0
)

type StatsNotifyJob struct {
	enable         bool
	xrayService    service.XrayService
	inboundService service.InboundService
	settingService service.SettingService
}

func NewStatsNotifyJob() *StatsNotifyJob {
	return new(StatsNotifyJob)
}

func (j *StatsNotifyJob) SendMsgToTgbot(msg string) {
	//Telegram bot basic info
	tgBottoken, err := j.settingService.GetTgBotToken()
	if err != nil {
		logger.Warning("sendMsgToTgbot failed,GetTgBotToken fail:", err)
		return
	}
	tgBotid, err := j.settingService.GetTgBotChatId()
	if err != nil {
		logger.Warning("sendMsgToTgbot failed,GetTgBotChatId fail:", err)
		return
	}

	bot, err := tgbotapi.NewBotAPI(tgBottoken)
	if err != nil {
		fmt.Println("get tgbot error:", err)
		return
	}
	bot.Debug = true
	fmt.Printf("Authorized on account %s", bot.Self.UserName)
	info := tgbotapi.NewMessage(int64(tgBotid), msg)
	//msg.ReplyToMessageID = int(tgBotid)
	bot.Send(info)
}

//Here run is a interface method of Job interface
func (j *StatsNotifyJob) Run() {
	if !j.xrayService.IsXrayRunning() {
		return
	}
	var info string
	//get hostname
	name, err := os.Hostname()
	if err != nil {
		fmt.Println("get hostname error:", err)
		return
	}
	info = fmt.Sprintf("Tên máy chủ:%s\r\n", name)
	//get ip address
	var ip string
	netInterfaces, err := net.Interfaces()
	if err != nil {
		fmt.Println("net.Interfaces failed, err:", err.Error())
		return
	}

	for i := 0; i < len(netInterfaces); i++ {
		if (netInterfaces[i].Flags & net.FlagUp) != 0 {
			addrs, _ := netInterfaces[i].Addrs()

			for _, address := range addrs {
				if ipnet, ok := address.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
					if ipnet.IP.To4() != nil {
						ip = ipnet.IP.String()
						break
					} else {
						ip = ipnet.IP.String()
						break
					}
                                }
                        }
                }
        }

	info += fmt.Sprintf("Địa Chỉ IP: %s\r\n \r\n", ip)

	//get traffic
	inbouds, err := j.inboundService.GetAllInbounds()
	if err != nil {
		logger.Warning("StatsNotifyJob run failed:", err)
		return
	}
	//NOTE:If there no any sessions here,need to notify here
	//TODO:分节点推送,自动转化格式
	for _, inbound := range inbouds {
		info += fmt.Sprintf("Tên Server: %s\r\nPort:%d\r\nLưu lượng tải lên ↑: %s\r\nLưu lượng tải xuống ↓: %s\r\nTổng lưu lượng truy cập: %s\r\n \r\n", inbound.Remark, inbound.Port, common.FormatTraffic(inbound.Up), common.FormatTraffic(inbound.Down), common.FormatTraffic((inbound.Up + inbound.Down)))
		if inbound.ExpiryTime == 0 {
			info += fmt.Sprintf("Hạn sử dụng: Vô thời hạn\r\n \r\n")
		} else {
			info += fmt.Sprintf("Hạn sử dụng: %s\r\n \r\n", time.Unix((inbound.ExpiryTime/1000), 0).Format("2006-01-02 15:04:05"))
		}
	}
	j.SendMsgToTgbot(info)
}

func (j *StatsNotifyJob) UserLoginNotify(username string, ip string, time string, status LoginStatus) {
	if username == "" || ip == "" || time == "" {
		logger.Warning("UserLoginNotify failed,invalid info")
		return
	}
	var msg string
	//get hostname
	name, err := os.Hostname()
	if err != nil {
		fmt.Println("get hostname error:", err)
		return
	}
	//msg = fmt.Sprintf("Có phiên ₫ăng nhập mới vào máy chủ\r\nhostname: %s\r\n", name)
	if status == LoginSuccess {
		msg = fmt.Sprintf("Đăng nhập thành công bảng điều khiển\r\nCPU:%s\r\n", name)
	} else if status == LoginFail {
		msg = fmt.Sprintf("đăng nhập bảng điều khiển không thành công\r\nCPU:%s\r\n", name)
	}
	msg += fmt.Sprintf("Thời gian: %s\r\n", time)
	msg += fmt.Sprintf("Tài khoản: %s\r\n", username)
	msg += fmt.Sprintf("IP: %s\r\n", ip)
	j.SendMsgToTgbot(msg)
}

func (j *StatsNotifyJob) SSHStatusLoginNotify(xuiStartTime string) {
	getSSHUserNumber, error := exec.Command("bash", "-c", "who | awk  '{print $1}'|wc -l").Output()
	if error != nil {
		fmt.Println("getSSHUserNumber error:", error)
		return
	}
	//fmt.Printf("getSSHUserNumber:%s\r\n", common.ByteToString(getSSHUserNumber))
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
			fmt.Println("get hostname error:", err)
			return
		}
		//Time compare,need if x-ui got restart while ssh already exist users
		SSHLoginTime, error := exec.Command("bash", "-c", "who | awk  '{print $3,$4}'|tail -n 1 ").Output()
		if error != nil {
			fmt.Println("getLoginTime error:", error.Error())
			return
		}
		/*
			//TODO:time compare if x-ui get restart and there exist logging users
			XUIRunTime, error := exec.Command("bash", "-c", " systemctl status x-ui | grep Active| tail -n 1 | awk '{print $6,$7}' ").Output()
			if error != nil {
				fmt.Println("getXUIRunTime error:", error.Error())
				return
			}
		*/
		var SSHLoginTimeStr string
		SSHLoginTimeStr = common.ByteToString(SSHLoginTime)
		//can't use string to change []byte to string,there will cause encode error
		fmt.Printf("SSHLoginTime[%s]\r\n", SSHLoginTimeStr)
		fmt.Printf("XUIRunTime[%s]\r\n", xuiStartTime)
		t1, err := time.Parse("2006-01-02 15:04:05", SSHLoginTimeStr)
		t2, err := time.Parse("2006-01-02 15:04:05", xuiStartTime)
		if t1.Before(t2) || err != nil {
			fmt.Printf("SSHLogin[%s] early than XUI start[%s]\r\n", SSHLoginTimeStr, xuiStartTime)
		}

		SSHLoginUserName, error := exec.Command("bash", "-c", "who | awk  '{print $1}'|tail -n 1").Output()
		if error != nil {
			fmt.Println("getSSHLoginUserName error:", error.Error())
			return
		}

		SSHLoginIpAddr, error := exec.Command("bash", "-c", "who | awk  '{print $5}'|tail -n 1 | cut -d \"(\" -f2 | cut -d \")\" -f1 ").Output()
		if error != nil {
			fmt.Println("getSSHLoginIpAddr error:", error)
			return
		}

		SSHLoginInfo = fmt.Sprintf("Có phiên đăng nhập mới:\r\n")
		SSHLoginInfo += fmt.Sprintf("Tên Server: %s\r\n", name)
		SSHLoginInfo += fmt.Sprintf("SSH User: %s", SSHLoginUserName)
		SSHLoginInfo += fmt.Sprintf("Thời gian đăng nhập: %s", SSHLoginTime)
		SSHLoginInfo += fmt.Sprintf("IP Đăng nhập SSH: %s", SSHLoginIpAddr)
		SSHLoginInfo += fmt.Sprintf("Số User đăng nhập SSH hiện tại: %s", getSSHUserNumber)
		j.SendMsgToTgbot(SSHLoginInfo)
	}
}
