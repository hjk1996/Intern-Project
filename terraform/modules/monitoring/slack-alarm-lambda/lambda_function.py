import json
import logging
import os
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
from datetime import datetime

HOOK_URL = os.environ["SLACK_WEBHOOK_URL"]
SLACK_CHANNEL = os.environ["SLACK_CHANNEL"]

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    logger.info("Event: " + str(event))
    message = json.loads(event["Records"][0]["Sns"]["Message"])
    logger.info("Message: " + str(message))

    alarm_name = message["AlarmName"]
    new_state = message["NewStateValue"]
    reason = message["NewStateReason"]
    timestamp = message["StateChangeTime"]
    region = message["Region"]
    resource_type = message.get("Trigger", {}).get("Namespace", "Unknown")

    formatted_time = datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%S.%f%z").strftime(
        "%Y-%m-%d %H:%M:%S"
    )

    slack_message = {
        "channel": SLACK_CHANNEL,
        "username": "AlarmBot",
        "attachments": [
            {
                "fallback": f"Alarm {alarm_name} is now {new_state}",
                "color": "danger" if new_state == "ALARM" else "good",
                "title": f"CloudWatch Alarm - {alarm_name}",
                "fields": [
                    {"title": "State", "value": new_state, "short": True},
                    {"title": "Reason", "value": reason, "short": False},
                    {"title": "Timestamp", "value": formatted_time, "short": True},
                    {"title": "Region", "value": region, "short": True},
                    {"title": "Resource Type", "value": resource_type, "short": True},
                ],
            }
        ],
    }

    req = Request(HOOK_URL, json.dumps(slack_message).encode("utf-8"))
    try:
        response = urlopen(req)
        response.read()
        logger.info("Message posted")
    except HTTPError as e:
        logger.error("Request failed: %d %s", e.code, e.reason)
    except URLError as e:
        logger.error("Server connection failed: %s", e.reason)
