package controller

import (
	"github.com/gin-gonic/gin"
)

type XUIController struct {
	BaseController

	inboundController *InboundController
	settingController *SettingController
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
	g.GET("/infome",a.infome)
	g.GET("/setting", a.setting)

	a.inboundController = NewInboundController(g)
	a.settingController = NewSettingController(g)
}

func (a *XUIController) index(c *gin.Context) {
	html(c, "index.html", "Hệ Thống X-UI", nil)
}

func (a *XUIController) inbounds(c *gin.Context) {
	html(c, "inbounds.html", "Danh Sách Server", nil)
}

func (a *XUIController) infome(c *gin.Context) {
        html(c, "infome.html", "Thông Tin Của Tôi", nil)
}

func (a *XUIController) setting(c *gin.Context) {
	html(c, "setting.html", "Cài Đặt", nil)
}
