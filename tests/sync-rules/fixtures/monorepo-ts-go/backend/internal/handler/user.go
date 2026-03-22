package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type UserHandler struct{}

func (h *UserHandler) GetUser(c *gin.Context) {
	id := c.Param("id")
	c.JSON(http.StatusOK, gin.H{"id": id, "name": "Alice"})
}
