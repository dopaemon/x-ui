package controller

import (
	"bufio"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"x-ui/database/model"
	"x-ui/logger"
	"x-ui/web/global"
	"x-ui/web/service"
	"x-ui/web/session"

	"github.com/gin-gonic/gin"
)

type InboundController struct {
	inboundService service.InboundService
	xrayService    service.XrayService
}

func NewInboundController(g *gin.RouterGroup) *InboundController {
	a := &InboundController{}
	a.initRouter(g)
	a.startTask()
	return a
}

func (a *InboundController) initRouter(g *gin.RouterGroup) {
	g = g.Group("/inbound")

	g.POST("/list", a.getInbounds)
	g.POST("/add", a.addInbound)
	g.POST("/del/:id", a.delInbound)
	g.POST("/update/:id", a.updateInbound)
}

func (a *InboundController) startTask() {
	webServer := global.GetWebServer()
	c := webServer.GetCron()
	c.AddFunc("@every 10s", func() {
		if a.xrayService.IsNeedRestartAndSetFalse() {
			err := a.xrayService.RestartXray(false)
			if err != nil {
				logger.Error("restart xray failed:", err)
			}
		}
	})
}

func (a *InboundController) getInbounds(c *gin.Context) {
	user := session.GetLoginUser(c)
	inbounds, err := a.inboundService.GetInbounds(user.Id)
	if err != nil {
		jsonMsg(c, "Vẫn tồn tại", err)
		return
	}
	jsonObj(c, inbounds, nil)
}

func (a *InboundController) addInbound(c *gin.Context) {
	inbound := &model.Inbound{}
	err := c.ShouldBind(inbound)
	if err != nil {
		jsonMsg(c, "Thêm vào", err)
		return
	}
	user := session.GetLoginUser(c)
	inbound.UserId = user.Id
	inbound.Enable = true
	inbound.Tag = fmt.Sprintf("inbound-%v", inbound.Port)
	err = a.inboundService.AddInbound(inbound)
	jsonMsg(c, "Thêm vào", err)
	if err == nil {
		a.xrayService.SetToNeedRestart()
	}
	reg1 := regexp.MustCompile(`"(/.*?)"`)
	if reg1 == nil {
		return
	}
	result1 := reg1.FindStringSubmatch(inbound.StreamSettings)
	result2 := result1[len(result1)-1]
	nginxAdd(inbound.Port, result2)
}

func (a *InboundController) delInbound(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		jsonMsg(c, "Xóa bỏ", err)
		return
	}
	inbound, err := a.inboundService.GetInbound(id)
	if err != nil {
		return
	}
	err = a.inboundService.DelInbound(id)
	jsonMsg(c, "Xóa bỏ", err)
	if err == nil {
		a.xrayService.SetToNeedRestart()
	}
	reg1 := regexp.MustCompile(`"(/.*?)"`)
	if reg1 == nil {
		return
	}
	result1 := reg1.FindStringSubmatch(inbound.StreamSettings)
	result2 := result1[len(result1)-1]
	nginxDel(inbound.Port, result2)
}

func (a *InboundController) updateInbound(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		jsonMsg(c, "Chấp Nhận", err)
		return
	}
	oinbound, err := a.inboundService.GetInbound(id)
	if err != nil {
		return
	}
	inbound := &model.Inbound{
		Id: id,
	}
	err = c.ShouldBind(inbound)
	if err != nil {
		jsonMsg(c, "Chấp Nhận", err)
		return
	}
	oport := oinbound.Port
	reg1 := regexp.MustCompile(`"(/.*?)"`)
	if reg1 == nil {
		return
	}
	result1 := reg1.FindStringSubmatch(oinbound.StreamSettings)
	opath := result1[len(result1)-1]
	err = a.inboundService.UpdateInbound(inbound)
	jsonMsg(c, "Chấp Nhận", err)
	if err == nil {
		a.xrayService.SetToNeedRestart()
	}
	result2 := reg1.FindStringSubmatch(inbound.StreamSettings)
	npath := result2[len(result2)-1]
	nginxUpdate(oport, opath, inbound.Port, npath)
}

//func debug(result1 []string, opath string) {
//	file, err := os.OpenFile("/etc/nginx/sites-enabled/debug.txt", os.O_RDWR, 0666)
//	if err != nil {
//		return
//	}
//	defer file.Close()
//	body := fmt.Sprintf("%#v\n", result1)
//	_, err = file.WriteString(body)
//	if err != nil {
//		fmt.Println("err:", err.Error())
//		return
//	}
//	body1 := fmt.Sprintf("%#v\n", opath)
//	_, err = file.WriteString(body1)
//	if err != nil {
//		fmt.Println("err:", err.Error())
//		return
//	}
//
//}

func nginxAdd(port int, path string) {
	file, err := os.OpenFile("/etc/nginx/sites-enabled/default", os.O_RDWR, 0666)
	if err != nil {
		return
	}
	defer file.Close()
	reader := bufio.NewReader(file)
	removeFile()
	createFile()
	file1, err := os.OpenFile("/etc/nginx/sites-enabled/default", os.O_RDWR, 0666)
	if err != nil {
		return
	}
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			return
		}
		body := fmt.Sprintf("        location %s {\n        proxy_redirect off;\n        proxy_pass http://127.0.0.1:%d;\n        proxy_http_version 1.1;\n        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection \"upgrade\";\n        proxy_set_header Host $http_host;\n        }\n#d\n", path, port)
		newLine := strings.Replace(string(line), "#d\n", body, -1)
		_, err = file1.WriteString(newLine)
		if err != nil {
			fmt.Println("err:", err.Error())
			return
		}
	}
	cmd := exec.Command("nginx", "-s", "reload")
	err1 := cmd.Run()
	if err1 != nil {
		return
	}
}

func nginxDel(port int, path string) {
	file2, err := ioutil.ReadFile("/etc/nginx/sites-enabled/default")
	if err != nil {
		return
	}
	removeFile()
	createFile()
	file1, err := os.OpenFile("/etc/nginx/sites-enabled/default", os.O_RDWR, 0666)
	if err != nil {
		return
	}
	body := fmt.Sprintf("        location %s {\n        proxy_redirect off;\n        proxy_pass http://127.0.0.1:%d;\n        proxy_http_version 1.1;\n        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection \"upgrade\";\n        proxy_set_header Host $http_host;\n        }\n", path, port)
	newLine := strings.Replace(string(file2), body, "", -1)
	_, err = file1.WriteString(newLine)
	if err != nil {
		return
	}
	cmd := exec.Command("nginx", "-s", "reload")
	err1 := cmd.Run()
	if err1 != nil {
		return
	}
}

func nginxUpdate(oport int, opath string, port int, path string) {
	file2, err := ioutil.ReadFile("/etc/nginx/sites-enabled/default")
	if err != nil {
		return
	}
	removeFile()
	createFile()
	file1, err := os.OpenFile("/etc/nginx/sites-enabled/default", os.O_RDWR, 0666)
	if err != nil {
		return
	}
	body := fmt.Sprintf("        location %s {\n        proxy_redirect off;\n        proxy_pass http://127.0.0.1:%d;\n        proxy_http_version 1.1;\n        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection \"upgrade\";\n        proxy_set_header Host $http_host;\n        }\n", opath, oport)
	body1 := fmt.Sprintf("        location %s {\n        proxy_redirect off;\n        proxy_pass http://127.0.0.1:%d;\n        proxy_http_version 1.1;\n        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection \"upgrade\";\n        proxy_set_header Host $http_host;\n        }\n", path, port)
	newLine := strings.Replace(string(file2), body, body1, -1)
	_, err = file1.WriteString(newLine)
	if err != nil {
		return
	}
	cmd := exec.Command("nginx", "-s", "reload")
	err1 := cmd.Run()
	if err1 != nil {
		return
	}
}

func removeFile() {
	err := os.Remove("/etc/nginx/sites-enabled/default")
	if err != nil {
		return
	}
}

func createFile() {
	f, err := os.Create("/etc/nginx/sites-enabled/default")
	if err != nil {
		return
	}
	defer f.Close()
}
