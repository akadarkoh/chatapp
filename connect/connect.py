import boto3 # type: ignore

dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table('WebSocketConnections')

def lambda_handler(event, context):
    connection_id = event["requestContext"]["connectionId"]

    connections_table.put_item(
        Item = 
        {
            'ConnectionID': connection_id
        }
    )
    return {"statusCode": 200, "body": "Connected."}
    
