package models

import (
	"gorm.io/gorm"
)

type Employee struct {
	gorm.Model
	ID       uint `gorm:"primaryKey"`
	Name     string
	Articles []Article `gorm:"foreignKey:EmployeeID"`
}

func (Employee) TableName() string {
	return "employees"
}
