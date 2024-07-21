import json
import boto3
import os 


CLUSTER_NAME = os.environ.get('CLUSTER_NAME')
SERVICE_NAME = os.environ.get('SERVICE_NAME')
DESIRED_COUNT = os.environ.get('DESIRED_COUNT')



def lambda_handler(event, context):
    client = boto3.client('ecs')
    scale_up_ecs_service(CLUSTER_NAME, SERVICE_NAME, client)
    return {
        'statusCode': 200,
        'body': json.dumps('Successfully scaled ECS service')
    }


def scale_up_ecs_service(cluster_name, service_name, client):
    response = client.update_service(
    cluster=cluster_name,
    service=service_name,
    desiredCount=DESIRED_COUNT)
    print(response)