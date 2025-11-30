# s3-to-sns-notification

# Creating an SNS Notification for your s3 Uploads

*When someone uploads to an S3 bucket you will recieve a notification*


### Step 1: Create an S3 Bucket

1. Go to your AWS Console and search S3 then select S3.

![](/attachments/select-s3.png)

2. Click create Bucket.

![](/attachments/create-bucket.png)

3. Give bucket a unique name as buckets require global uniqueness.<s3snslambda-project>

4. Make sure you know the region you are in, (us-east-1)

5. Go to the bottom of the screen and create bucket.

![](/attachments/create-bucket.png)

### Step 2: Create an SNS Topic

1. In your AWS Console search SNS and select Simple Notification Service.
(open link in new tab by right clicking and selecting open link in new tab)

2. Click Topics in the left pane of screen.

![](/attachments/select-topic.png)

3. Create Topic.

![](/attachments/create-topic.png)

4. Select Standard Topic.

![](/attachments/select-standard.png)

5. Enter a name for the Topic (e.g., s3-email-notification)

![](/attachments/name-topic.png)

6. Create topic.

![](/attachments/create-topic.png)

**You must also put a name in the display name**

7. Copy the Arn for SNS as you will need this later.
(arn:)

### Step 3: Create Subscription (Email)

1. Click Create Subscription.

![](/attachments/create-subscription.png)

2. Select Protocol <email>

![](/attachments/select-protocol.png)

3. Make your email the endpoint.

4. Create Subscription.

![](/attachments/create-subscription.png)

5. Check your email to confirm subscription. (check spam if you don't see it)

### Step 4: Create a Lambda Function

1. Search Lambda in the search bar and select Lambda.

![](/attachments/select-lambda.png)

2. Select Create Function.

![](/attachments/create-function.png)

3. Author from Scratch.

![](/attachments/a-f-s.png)

4. Name Function S3toSNSLambda.

5. Runtime Select Pyhton 3.?

6. Expand "Change Default Execution Role under permissions."
        Choose "Create a new role with basic Lambda Permissions."

![](/attachments/lamda-config.png)

7. Click Create Function

![](/attachments/create-function.png)

### Step 5: Add Code to Lambda

1. Open the Lambda Function.

2. Scroll down to Code Source.

3. Replace Default Code with:


'''py
    
    import json
    import boto3
    import os
    import traceback
    import logging

    #Set up logging
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    sns_client = boto3.client('sns')

    #Safer environment variable access with default/fallback
    SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')

    def lambda_handler(event, context):
        try:
            # Validate SNS topic ARN
            if not SNS_TOPIC_ARN:
                logger.error("SNS_TOPIC_ARN environment variable is missing or empty")
                return {
                    "statusCode": 500, 
                    "body": json.dumps("SNS_TOPIC_ARN environment variable is missing")
                }
            
            #Validate event structure
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
                    # Safe extraction with defaults
                    s3_data = record.get('s3', {})
                    bucket_data = s3_data.get('bucket', {})
                    object_data = s3_data.get('object', {})
                    
                    bucket_name = bucket_data.get('name', 'Unknown')
                    object_key = object_data.get('key', 'Unknown')
                    event_time = record.get('eventTime', 'Unknown')
                    event_name = record.get('eventName', 'Unknown')
                    region = record.get('awsRegion', 'Unknown')
                    object_size = object_data.get('size', 'Unknown')
                    
                    logger.info(f"Processing record {i+1}: bucket={bucket_name}, key={object_key}")
                    
                    # Format the email content
                    message = (
                        f"New S3 Upload Notification\n\n"
                        f"Bucket: {bucket_name}\n"
                        f"File: {object_key}\n"
                        f"Size: {object_size} bytes\n"
                        f"Event Time: {event_time}\n"
                        f"Region: {region}\n"
                        f"Event Type: {event_name}\n\n"
                        f"View the file: https://s3.console.aws.amazon.com/s3/object/{bucket_name}?region={region}&prefix={object_key}"
                    )

                    # Send notification
                    sns_client.publish(
                        TopicArn=SNS_TOPIC_ARN,
                        Message=message,
                        Subject="S3 Upload Notification"
                    )
                    
                    logger.info(f"Successfully sent notification for {object_key}")
                    sent_count += 1
                    
                except Exception as record_error:
                    logger.error(f"Failed to process record {i+1}: {str(record_error)}\n{traceback.format_exc()}")
                    continue  # Continue processing other records
            
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

'''py



(Thx Derrick) <https://github.com/derrickSh43/SNSfromS3withLambda/blob/main/SNS.py>

4. Click Deploy

### Step 6: Attach SNS Publish Permissions to Lambda

1. Go to the IAM Console, Select Roles.

2. Find the IAM Role that was created for the Lambda Function
        (S3ToSNSLambda)

3. Click on the permissions, add the permissions, attach policies.

4. Search for and attach:
AWSLambdaBasicExecutionRole
AmazonSNSFullAccess (or create a custom policy with sns:Publish)

### Step 7: Attach SNS Policy to Allow Lambda to Publish

1. Go back to SNS Tab.

2. Click on your SNS Topic.

3. Scroll down to Access Policy section and edit Poicy.

![](/attachments/attach-policies.png)

Replace the existing policy with the following (update Your_Account_Number_Here and Lambda function name):


'''
      
        {
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:us-east-1:Your_account_number_here:s3-email-notification",
        "Condition": {
            "ArnEquals": {
            "aws:SourceArn": "arn:aws:lambda:us-east-1:Your_account_number_here:function:S3ToSNSLambda"
            }
        }
        }
    ]
    }

'''

4. Click Save Changes.

### Step 8: Configure S3# to Trigger Lambda

1. Go to S3 Tab.

2. Open your s3 bucket (s3snslambda-project)

3. Click Properties, scroll to Event Notifications

![](/attachments/select-properties.png)

4. Click Create Event Notification.

![](/attachments/event-notification.png)

5. Event name (TriggerLambdaOnUpload)

6. Event types (All object create events [PUT])

![](/attachments/put.png)

7. Destination -> Select Lambda Function

8. Choose S3toSNSLambda.

9. Click Save.


### Step 9: Test Setup

1. Go to S3 and upload a file into your bucket.

2. Wait a few seconds to a few minutes.

3. Check your email inbox for the SNS notification.

![](/attachments/confirmation.png)



### Troubleshooting if there is no delivery

1. First test sns directly from the console, if working then go to role and 
    check that you gave proper permissions.

2. If doesn't work still retry entire and be very careful.

3. Check to make sure your topic ARN is in the python code where the environment variable is being created...

