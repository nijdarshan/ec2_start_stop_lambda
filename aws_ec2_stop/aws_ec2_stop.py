import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.resource('ec2')
client_name = os.getenv('CLIENT_NAME')

def lambda_handler(event, context):

    filters = [{
            'Name': 'tag:Client',
            'Values': [client_name]
        },
        {
            'Name': 'instance-state-name', 
            'Values': ['running']
        }
    ]
    
    instances = ec2.instances.filter(Filters=filters)
    
    runningInstances = [instance.id for instance in instances]
    
    if len(runningInstances) > 0:
        shuttingDown = ec2.instances.filter(InstanceIds=runningInstances).stop()
        print(f"Shuttingdown {len(runningInstances)} {client_name} instances with ID - {runningInstances}")
    else:
        print(f"No {client_name} instances are not running")
