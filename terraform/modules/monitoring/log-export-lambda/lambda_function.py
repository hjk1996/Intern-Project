import os
from datetime import datetime, timedelta

import boto3


DESTINATION_BUCKET = os.environ["DESTINATION_BUCKET"]
LOG_GROUP_NAME = os.environ["GROUP_NAME"]


# 어제 날짜의 로그를 S3로 export
def lambda_handler(event, context):

    cur_time = datetime.now()
    yesterday = cur_time - timedelta(days=1)
    from_time = yesterday.replace(hour=0, minute=0, second=0, microsecond=0)
    from_time = int(from_time.timestamp() * 1000)
    to_time = yesterday.replace(hour=23, minute=59, second=59, microsecond=999999)
    to_time = int(to_time.timestamp() * 1000)
     
    client = boto3.client('logs')
    response = client.create_export_task(
        taskName='export_task',
        logGroupName=LOG_GROUP_NAME,
        fromTime=from_time,
        to=to_time,
        destination=DESTINATION_BUCKET,
        destinationPrefix=f'exported_logs/{yesterday.strftime("%Y/%m/%d")}'
    )




