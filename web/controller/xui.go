package controller

import (
	"github.com/gin-gonic/gin"
)

type XUIController struct {
	BaseController

	inboundController *InboundController
	settingController *SettingController
	// fastController *FastController
	// speedtestController *SpeedtestController
}

func NewXUIController(g *gin.RouterGroup) *XUIController {
	a := &XUIController{}
	a.initRouter(g)
	return a
}

func (a *XUIController) initRouter(g *gin.RouterGroup) {
	g = g.Group("/xui")
	g.Use(a.checkLogin)

	g.GET("/", a.index)
	g.GET("/inbounds", a.inbounds)
	g.GET("/setting", a.setting)
	g.GET("/fast", a.fast)
	g.GET("/speedtest", a.speedtest)

	a.inboundController = NewInboundController(g)
	a.settingController = NewSettingController(g)
	// a.fastController = NewFastController(g)
	// a.speedtestController = NewSpeedtestController(g)
}

func (a *XUIController) index(c *gin.Context) {
	html(c, "index.html", "Hệ Thống X-UI", nil)
}

func (a *XUIController) inbounds(c *gin.Context) {
	html(c, "inbounds.html", "Danh Sách Server", nil)
}

func (a *XUIController) setting(c *gin.Context) {
	html(c, "setting.html", "Cài Đặt", nil)
}

func (a *XUIController) fast(c *gin.Context) {
        html(c, "fast.html", "fast", nil)
}

func (a *XUIController) speedtest(c *gin.Context) {
        html(c, "speedtest.html", "speedtest", nil)
}
