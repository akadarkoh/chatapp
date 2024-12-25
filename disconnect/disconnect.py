import boto3 # type: ignore

dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table('WebSocketConnections')

def lambda_handler(event, context):
    connection_id = event["requestContext"]["connectionId"]
    
    # Remove connection ID from DynamoDB
    connections_table.delete_item(
        Key={
            "ConnectionID": connection_id
        }
    )

    return {"statusCode": 200}
