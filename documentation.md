# S3 Upload Notification Pipeline
### Using Amazon S3, SNS, and Lambda

> **What this guide builds:** An automated email notification system that triggers whenever a file is uploaded to an S3 bucket. When an object is created, S3 invokes a Lambda function, which publishes a formatted message to an SNS topic that delivers it to your email address.

---

## Prerequisites

- An active AWS account with permissions to create S3, SNS, Lambda, and IAM resources
- Access to the AWS Management Console
- A valid email address to receive notifications

---

## Architecture Overview

```
S3 Bucket
    │  (ObjectCreated event)
    ▼
Lambda Function  ──►  SNS Topic  ──►  Email Subscription
```

---

## Step 1: Create an S3 Bucket

1. In the AWS Console search bar, type **S3** and select **S3**.
2. Click **Create bucket**.
3. Enter a globally unique bucket name (e.g., `s3snslambda-project`).
   > S3 bucket names must be globally unique across all AWS accounts and regions.
4. Confirm your target region (e.g., `us-east-1`). Note this — you will need it in later steps.
5. Leave all other settings at their defaults and click **Create bucket**.

---

## Step 2: Create an SNS Topic

1. In the AWS Console search bar, type **SNS** and select **Simple Notification Service**.
2. In the left navigation pane, click **Topics**.
3. Click **Create topic**.
4. Select **Standard** as the topic type.
5. Enter a name for the topic (e.g., `s3-email-notification`).
6. In the **Display name** field, enter a display name. This field is required — it appears as the sender name in delivered emails.
7. Click **Create topic**.
8. On the topic detail page, copy the **ARN** and save it. You will need it when configuring the Lambda environment variable.

---

## Step 3: Create an Email Subscription

1. On the topic detail page, click **Create subscription**.
2. Set **Protocol** to `Email`.
3. Set **Endpoint** to the email address where you want to receive notifications.
4. Click **Create subscription**.
5. Open your email inbox and confirm the subscription by clicking the link in the confirmation email AWS sends.
   > Check your spam folder if the email does not appear within a few minutes. The subscription will remain in `PendingConfirmation` status until you confirm it — notifications will not be delivered until this step is complete.

---

## Step 4: Create a Lambda Function

1. In the AWS Console search bar, type **Lambda** and select **Lambda**.
2. Click **Create function**.
3. Select **Author from scratch**.
4. Configure the function with the following settings:

   | Field | Value |
   |---|---|
   | Function name | `S3ToSNSLambda` |
   | Runtime | Python 3.12 (or latest available) |
   | Execution role | Create a new role with basic Lambda permissions |

5. Click **Create function**.

---

## Step 5: Deploy the Lambda Function Code

1. Open the Lambda function you just created.
2. Scroll down to the **Code source** section.
3. Replace the default handler code with the following:

```python
import json
import boto3
import os
import traceback
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client('sns')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')

def lambda_handler(event, context):
    try:
        # Validate SNS topic ARN is configured
        if not SNS_TOPIC_ARN:
            logger.error("SNS_TOPIC_ARN environment variable is missing or empty")
            return {
                "statusCode": 500,
                "body": json.dumps("SNS_TOPIC_ARN environment variable is missing")
            }

        # Validate event structure
        if not isinstance(event, dict):
            logger.error("Event is not a dict")
            return {"statusCode": 400, "body": "Invalid event format"}

        records = event.get('Records', [])
        if not records:
            logger.warning("No records found in event")
            return {"statusCode": 400, "body": "No records found"}

        sent_count = 0
        for i, record in enumerate(records):
            try:
                s3_data     = record.get('s3', {})
                bucket_data = s3_data.get('bucket', {})
                object_data = s3_data.get('object', {})

                bucket_name = bucket_data.get('name', 'Unknown')
                object_key  = object_data.get('key', 'Unknown')
                event_time  = record.get('eventTime', 'Unknown')
                event_name  = record.get('eventName', 'Unknown')
                region      = record.get('awsRegion', 'Unknown')
                object_size = object_data.get('size', 'Unknown')

                logger.info(f"Processing record {i+1}: bucket={bucket_name}, key={object_key}")

                message = (
                    f"New S3 Upload Notification\n\n"
                    f"Bucket: {bucket_name}\n"
                    f"File:   {object_key}\n"
                    f"Size:   {object_size} bytes\n"
                    f"Time:   {event_time}\n"
                    f"Region: {region}\n"
                    f"Event:  {event_name}\n\n"
                    f"View file: https://s3.console.aws.amazon.com/s3/object/{bucket_name}"
                    f"?region={region}&prefix={object_key}"
                )

                sns_client.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Message=message,
                    Subject="S3 Upload Notification"
                )

                logger.info(f"Successfully sent notification for {object_key}")
                sent_count += 1

            except Exception as record_error:
                logger.error(
                    f"Failed to process record {i+1}: {str(record_error)}\n"
                    f"{traceback.format_exc()}"
                )
                continue

        return {
            "statusCode": 200,
            "body": json.dumps(f"Successfully sent {sent_count} notifications")
        }

    except Exception as e:
        logger.error(f"Lambda handler failed: {str(e)}\n{traceback.format_exc()}")
        return {
            "statusCode": 500,
            "body": json.dumps(f"Lambda execution failed: {str(e)}")
        }
```

> **Credit:** Original function by [Derrick](https://github.com/derrickSh43/SNSfromS3withLambda/blob/main/SNS.py)

4. Click **Deploy**.

5. Scroll up to the **Configuration** tab, select **Environment variables**, and add the following:

   | Key | Value |
   |---|---|
   | `SNS_TOPIC_ARN` | The SNS topic ARN you copied in Step 2 |

---

## Step 6: Grant Lambda Permission to Publish to SNS

1. In the AWS Console, navigate to **IAM → Roles**.
2. Find and open the execution role that was created for `S3ToSNSLambda`.
3. Click **Add permissions → Attach policies**.
4. Attach the following policies:

   | Policy | Purpose |
   |---|---|
   | `AWSLambdaBasicExecutionRole` | Allows Lambda to write logs to CloudWatch |
   | `AmazonSNSFullAccess` | Allows Lambda to publish to SNS topics |

   > For production environments, replace `AmazonSNSFullAccess` with a custom inline policy scoped to `sns:Publish` on your specific topic ARN only.

---

## Step 7: Update the SNS Topic Access Policy

1. Navigate back to your SNS topic in the SNS console.
2. Scroll down to the **Access policy** section and click **Edit**.
3. Replace the existing policy with the following, substituting your account number and region:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "SNS:Publish",
      "Resource": "arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:s3-email-notification",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:lambda:us-east-1:YOUR_ACCOUNT_ID:function:S3ToSNSLambda"
        }
      }
    }
  ]
}
```

4. Click **Save changes**.

---

## Step 8: Configure S3 to Trigger Lambda

1. Navigate to your S3 bucket in the S3 console.
2. Click the **Properties** tab.
3. Scroll down to **Event notifications** and click **Create event notification**.
4. Configure the notification with the following settings:

   | Field | Value |
   |---|---|
   | Event name | `TriggerLambdaOnUpload` |
   | Event types | `s3:ObjectCreated:Put` |
   | Destination | Lambda function |
   | Lambda function | `S3ToSNSLambda` |

5. Click **Save changes**.

---

## Step 9: Test the Pipeline

1. Navigate to your S3 bucket and upload any file.
2. Wait 15–30 seconds.
3. Check your email inbox for a notification with the file name, size, region, and a direct console link.

A successful notification will look similar to this:

```
Subject: S3 Upload Notification

New S3 Upload Notification

Bucket: s3snslambda-project
File:   example.pdf
Size:   204800 bytes
Time:   2025-01-15T14:32:01.000Z
Region: us-east-1
Event:  ObjectCreated:Put

View file: https://s3.console.aws.amazon.com/s3/object/...
```

---

## Troubleshooting

| Symptom | Likely Cause | Resolution |
|---|---|---|
| No email received | Subscription not confirmed | Check your inbox/spam for the AWS confirmation email and click the link |
| No email received | `SNS_TOPIC_ARN` not set | Verify the environment variable is configured on the Lambda function |
| Lambda execution error | Missing IAM permissions | Confirm `AWSLambdaBasicExecutionRole` and `sns:Publish` are attached to the Lambda role |
| Lambda not triggered | S3 event notification misconfigured | Confirm the event type is `s3:ObjectCreated:Put` and destination is set to the correct Lambda function |
| SNS publish error | Topic access policy too restrictive | Verify the `aws:SourceArn` condition in the SNS topic policy matches the Lambda function ARN exactly |

For deeper investigation, open **CloudWatch → Log groups → /aws/lambda/S3ToSNSLambda** to review Lambda execution logs for each invocation.