package models

import (
	"time"

	"gorm.io/gorm"
)


type Article struct {
	gorm.Model
	ID         uint `gorm:"primaryKey"`
	Content    string
	CreatedAt  time.Time
}

func (Article) TableName() string {
	return "articles"
}
