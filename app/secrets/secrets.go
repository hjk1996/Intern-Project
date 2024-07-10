package secrets

import (
	"context"
	"encoding/json"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
)

type DBSecret struct {
	User     string `json:"username"`
	Password string `json:"password"`
}

func GetDBSecret(secretName string, region string) (DBSecret, error) {

	var secret DBSecret

	cfg, err := config.LoadDefaultConfig(context.TODO(), config.WithRegion(region))
	if err != nil {
		return secret, err
	}

	svc := secretsmanager.NewFromConfig(cfg)

	input := &secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretName),
	}

	result, err := svc.GetSecretValue(context.TODO(), input)

	if err != nil {
		return secret, err
	}

	err = json.Unmarshal([]byte(*result.SecretString), &secret)

	if err != nil {
		return secret, err
	}

	return secret, err
}
