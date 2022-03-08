import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.resource('ec2')
client_name = os.getenv('CLIENT_NAME')

def lambda_handler(pr, context):

    filters = [{
            'Name': 'tag:Client',
            'Values': [client_name]
        },
        {
            'Name': 'instance-state-name', 
            'Values': ['stopped']
        }
    ]

    instances = ec2.instances.filter(Filters=filters)
    
    stoppedInstances = [instance.id for instance in instances]
    
    if len(stoppedInstances) > 0:
        startingUp = ec2.instances.filter(InstanceIds=stoppedInstances).start()
        print (f"Starting {len(stoppedInstances)} {client_name} instances with ID - {stoppedInstances}")
    else:
        printcli
