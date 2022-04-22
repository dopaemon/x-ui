package job

import (
	"fmt"
	"net"
	"os"
	"time"
	"x-ui/logger"
	"x-ui/util/common"
	"x-ui/web/service"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
)

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
