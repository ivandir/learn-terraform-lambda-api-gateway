import os, json

def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({"message":"{} from Lambda!".format(os.environ['greeting'])})
    }

