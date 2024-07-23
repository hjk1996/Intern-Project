import boto3
import os
import json


ecs_client = boto3.client('ecs')

def lambda_handler(event, context):
    cluster = os.environ['ECS_CLUSTER_NAME']
    service = os.environ['ECS_SERVICE_NAME']

    # Update ECS Service
    response = ecs_client.update_service(
        cluster=cluster,
        service=service,
        forceNewDeployment=True
    )

    print(f"Update service response: {response}")
    return json.dumps(response, default=str)

