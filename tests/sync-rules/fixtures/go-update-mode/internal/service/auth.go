package service

import (
	"errors"
	"fmt"
)

type AuthService struct{}

func (s *AuthService) Authenticate(token string) (string, error) {
	if token == "" {
		return "", errors.New("empty token")
	}
	return fmt.Sprintf("user-%s", token[:8]), nil
}
