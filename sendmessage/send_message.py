import boto3  # type: ignore
import json
import datetime

# Initialize resources
dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table('WebSocketConnections')
messages_table = dynamodb.Table('ChatMessages')
apigateway = boto3.client('apigatewaymanagementapi', endpoint_url="wss://your-api-id.execute-api.us-east-1.amazonaws.com/production")

def lambda_handler(event, context):
    try:
        # Parse the incoming event
        body = json.loads(event["body"])
        session_id = body["sessionId"]
        message = body["message"]

        # Save message to DynamoDB
        timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
        messages_table.put_item(
            Item={
                "SessionID": session_id,
                "Timestamp": timestamp,
                "Content": message
            }
        )

        # Fetch all connections (with pagination)
        response = connections_table.scan()
        connections = response["Items"]

        # Iterate over connections and send the message
        for connection in connections:
            connection_id = connection["ConnectionID"]
            try:
                apigateway.post_to_connection(
                    ConnectionId=connection_id,
                    Data=json.dumps({"message": message})
                )
            except apigateway.exceptions.GoneException:
                # Remove stale connections
                connections_table.delete_item(
                    Key={"ConnectionID": connection_id}
                )
            except Exception as e:
                print(f"Failed to send message to {connection_id}: {e}")

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Message sent successfully"})
        }

    except Exception as e:
        print(f"Error handling request: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal Server Error"})
        }
