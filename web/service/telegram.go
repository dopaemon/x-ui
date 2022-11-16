package service

import (
	"fmt"
	"log"
	"os"
	"runtime"
	"strconv"
	"time"
	"x-ui/logger"
	"x-ui/util/common"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
	"github.com/shirou/gopsutil/host"
	"github.com/shirou/gopsutil/load"
)

// This should be global variable, and only one instance
var botInstace *tgbotapi.BotAPI

// Structural types can be accessed by other bags
type TelegramService struct {
	xrayService    XrayService
	serverService  ServerService
	inboundService InboundService
	settingService SettingService
}

func (s *TelegramService) GetsystemStatus() string {
	var status string
	// get hostname
	name, err := os.Hostname()
	if err != nil {
		fmt.Println("Nhận tên máy chủ lỗi: ", err)
		return ""
	}

	status = fmt.Sprintf(" Tên máy chủ: %s\r\n", name)
	status += fmt.Sprintf(" Hệ thống: %s\r\n", runtime.GOOS)
	status += fmt.Sprintf(" CPU Load: %s\r\n", runtime.GOARCH)

	avgState, err := load.Avg()
	if err != nil {
		logger.Warning("tải avg thất bại: ", err)
	} else {
		status += fmt.Sprintf(" Tải hệ thống: %.2f, %.2f, %.2f\r\n", avgState.Load1, avgState.Load5, avgState.Load15)
	}

	upTime, err := host.Uptime()
	if err != nil {
		logger.Warning("nhận thời gian hoạt động không thành công: ", err)
	} else {
		status += fmt.Sprintf(" Thời gian hoạt động: %s\r\n", common.FormatTime(upTime))
	}

	// xray version
	status += fmt.Sprintf(" Phiên bản X-Ray hiện tại: %s\r\n", s.xrayService.GetXrayVersion())

	// ip address
	var ip string
	ip = common.GetMyIpAddr()
	status += fmt.Sprintf(" Địa chỉ IP: %s\r\n \r\n", ip)

	// get traffic
	inbouds, err := s.inboundService.GetAllInbounds()
	if err != nil {
		logger.Warning("StatsNotifyJob run error: ", err)
	}

	for _, inbound := range inbouds {
		status += fmt.Sprintf(" Tên node: %s\r\n Cổng: %d\r\nTổng lượng tải lên ↑: %s\r\nTổng lượng tải xuống ↓: %s\r\nTổng lưu lượng: %s\r\n", inbound.Remark, inbound.Port, common.FormatTraffic(inbound.Up), common.FormatTraffic(inbound.Down), common.FormatTraffic((inbound.Up + inbound.Down)))
		if inbound.ExpiryTime == 0 {
			status += fmt.Sprintf("⌚ Understanding time: indefinitely\r\n \r\n")
		} else {
			status += fmt.Sprintf("❗ Ngày hết hạn: %s\r\n \r\n", time.Unix((inbound.ExpiryTime/1000), 0).Format("2006-01-02 15:04:05"))
		}
	}
	return status
}

func (s *TelegramService) StartRun() {
	logger.Info("Dịch vụ telegram đã sẵn sàng chạy")
	s.settingService = SettingService{}
	tgBottoken, err := s.settingService.GetTgBotToken()

	if err != nil || tgBottoken == "" {
		logger.Infof(" Khởi chạy dịch vụ telegram thất bại, GetTgBotToken fail, err: %v, tgBottoken: %s", err, tgBottoken)
		return
	}
	logger.Infof("TelegramService GetTgBotToken:%s", tgBottoken)

	botInstace, err = tgbotapi.NewBotAPI(tgBottoken)

	if err != nil {
		logger.Infof(" Khởi chạy dịch vụ telegram thất bại, NewBotAPI fail: %v, tgBottoken: %s", err, tgBottoken)
		return
	}
	botInstace.Debug = false
	fmt.Printf("Được ủy quyền trên tài khoản %s", botInstace.Self.UserName)

	// get all my commands
	commands, err := botInstace.GetMyCommands()
	if err != nil {
		logger.Warning(" Khởi chạy dịch vụ telegram bị lỗi, GetMyCommandsfail: ", err)
	}

	for _, command := range commands {
		fmt.Printf("Lệnh %s, Miêu tả: %s \r\n", command.Command, command.Description)
	}

	// get update
	chanMessage := tgbotapi.NewUpdate(0)
	chanMessage.Timeout = 60

	updates := botInstace.GetUpdatesChan(chanMessage)

	for update := range updates {
		if update.Message == nil {
			// NOTE:may there are different bot instance,we could use different bot endApiPoint
			updates.Clear()
			continue
		}

		if !update.Message.IsCommand() {
			continue
		}

		msg := tgbotapi.NewMessage(update.Message.Chat.ID, "")

		// Extract the command from the Message.
		switch update.Message.Command() {
		case "delete":
			inboundPortStr := update.Message.CommandArguments()
			inboundPortValue, err := strconv.Atoi(inboundPortStr)

			if err != nil {
				msg.Text = " Cổng vào không hợp lệ, vui lòng kiểm tra lại"
				break
			}

			//logger.Infof("Will delete port:%d inbound", inboundPortValue)
			error := s.inboundService.DelInboundByPort(inboundPortValue)
			if error != nil {
				msg.Text = fmt.Sprintf(" Xóa cổng port %d  thất bại", inboundPortValue)
			} else {
				msg.Text = fmt.Sprintf(" Xóa cổng port thành công", inboundPortValue)
			}

		case "restart":
			err := s.xrayService.RestartXray(true)
			if err != nil {
				msg.Text = fmt.Sprintln(" Khởi động lại dịch vụ X-Ray bị lỗi: ", err)
			} else {
				msg.Text = " Khởi động lại dịch vụ X-Ray thành công!"
			}

		case "disable":
			inboundPortStr := update.Message.CommandArguments()
			inboundPortValue, err := strconv.Atoi(inboundPortStr)
			if err != nil {
				msg.Text = " Cổng vào không hợp lệ, vui lòng kiểm tra lại"
				break
			}
			//logger.Infof("Will delete port:%d inbound", inboundPortValue)
			error := s.inboundService.DisableInboundByPort(inboundPortValue)
			if error != nil {
				msg.Text = fmt.Sprintf(" Vô hiệu hóa cổng port %d  thất bại: %s", inboundPortValue, error)
			} else {
				msg.Text = fmt.Sprintf(" Cổng port %d đã được vô hiệu hóa thành công", inboundPortValue)
			}

		case "enable":
			inboundPortStr := update.Message.CommandArguments()
			inboundPortValue, err := strconv.Atoi(inboundPortStr)
			if err != nil {
				msg.Text = "Cổng vào không hợp lệ, vui lòng kiểm tra lại"
				break
			}
			//logger.Infof("Will delete port:%d inbound", inboundPortValue)
			error := s.inboundService.EnableInboundByPort(inboundPortValue)
			if error != nil {
				msg.Text = fmt.Sprintf("Kích hoạt cổng port %d  thất bại: %s", inboundPortValue, error)
			} else {
				msg.Text = fmt.Sprintf("Cổng port %d đã được kích hoạt thành công ", inboundPortValue)
			}

		case "clear":
			inboundPortStr := update.Message.CommandArguments()
			inboundPortValue, err := strconv.Atoi(inboundPortStr)
			if err != nil {
				msg.Text = "Cổng vào không hợp lệ, vui lòng kiểm tra lại"
				break
			}
			error := s.inboundService.ClearTrafficByPort(inboundPortValue)
			if error != nil {
				msg.Text = fmt.Sprintf(" Đặt lại cổng port %d thất bại: %s", inboundPortValue, error)
			} else {
				msg.Text = fmt.Sprintf("Đặt lại cổng port %d thành công", inboundPortValue)
			}

		case "clearall":
			error := s.inboundService.ClearAllInboundTraffic()
			if error != nil {
				msg.Text = fmt.Sprintf(" Không thể xóa tất cả lưu lượng đến: %s", error)
			} else {
				msg.Text = fmt.Sprintf(" Tất cả các hệ thống lưu lượng đến đã được xóa sạch")
			}
        // DEPRIATED. UPDATING KERNAL INTO ANY UNSUPPORTED VERSIONS MAY BREAK THE OS
		// case "version":
		//	versionStr := update.Message.CommandArguments()
		//	currentVersion, _ := s.serverService.GetXrayVersions()
		//	if currentVersion[0] == versionStr {
		//		msg.Text = fmt.Sprint("Can't update the same version as the local X-UI XRAY kernel")
		//	}
		//	error := s.serverService.UpdateXray(versionStr)
		//	if error != nil {
		//		msg.Text = fmt.Sprintf("XRAY kernel version upgrade to %s failed, err: %s", versionStr, error)
		//	} else {
		//		msg.Text = fmt.Sprintf("XRAY kernel version upgrade to %s succeed", versionStr)
		//	}
		case "github":
			msg.Text = `https://github.com/quydang04/x-ui-vn/`

		case "status":
			msg.Text = s.GetsystemStatus()

		case "start":
			msg.Text = `Xin chào, chào mừng bạn đã đến bot quản lý của x-ui, vui lòng sử dụng lệnh /help để xem tất cả các lệnh nhé`
		default:
			msg.Text = `X-UI Vietnamese Version Bot Command

 			
| /help 		    
|- Để xem thông tin của bot
| 
| /delete [PORT] 
|- Xóa node của các cổng tương ứng
| 
| /restart 
|- Khởi động lại dịch vụ X-Ray
| 
| /status
|- Để xem trạng thái hiện tại của hệ thống
| 
| /enable [PORT]
|- Kích hoạt node của các cổng tương ứng
|
| /disable [PORT]
|- Vô hiệu hóa node của các cổng tương ứng
|
| /clear [PORT]
|- Xóa toàn bộ node của các cổng tương ứng
|
| /clearall 
|- Xóa toàn bộ lưu lượng về số 0
|
| /github
|- Để lấy liên kết dẫn đến dự án này trên github
|
`
}

		if _, err := botInstace.Send(msg); err != nil {
			log.Panic(err)
		}
	}

}

func (s *TelegramService) SendMsgToTgbot(msg string) {
	logger.Info("SendMsgToTgbot entered")
	tgBotid, err := s.settingService.GetTgBotChatId()
	if err != nil {
		logger.Warning("sendMsgToTgbot failed, GetTgBotChatId fail:", err)
		return
	}
	if tgBotid == 0 {
		logger.Warning("sendMsgToTgbot failed, GetTgBotChatId fail")
		return
	}

	info := tgbotapi.NewMessage(int64(tgBotid), msg)
	if botInstace != nil {
		botInstace.Send(info)
	} else {
		logger.Warning("bot instance is nil")
	}
}

// NOTE:This function can't be called repeatly
func (s *TelegramService) StopRunAndClose() {
	if botInstace != nil {
		botInstace.StopReceivingUpdates()
	}
}
