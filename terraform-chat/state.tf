terraform {
  backend "s3" {
    bucket = "chat-app-state-file"
    key = "websocket-chat-backend.tfstate"
    region = "us-east-2"
    dynamodb_table = "chatDB"
    encrypt = true
  }
}