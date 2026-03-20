package main

import (
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/example/api/internal/handler"
	"github.com/example/api/pkg/middleware"
)

func main() {
	logger, _ := zap.NewProduction()
	r := gin.Default()
	r.Use(middleware.Logger(logger))

	h := &handler.UserHandler{}
	r.GET("/users/:id", h.GetUser)
	r.POST("/users", h.CreateUser)

	r.Run(":8080")
}
