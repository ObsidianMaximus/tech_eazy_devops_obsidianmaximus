import boto3
import os

def lambda_handler(event, context):
    instance_id = event.get('instance_id') or os.environ.get('INSTANCE_ID')
    ec2 = boto3.client('ec2')
    ec2.stop_instances(InstanceIds=[instance_id])
    return {"status": "stopped", "instance_id": instance_id}