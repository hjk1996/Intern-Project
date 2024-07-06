package models

import "time"

type Attendance struct {
	UserId    string
	Timestamp time.Time
}
