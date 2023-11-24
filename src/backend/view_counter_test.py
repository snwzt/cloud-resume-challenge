import boto3

from moto import mock_dynamodb
from view_counter import lambda_handler

@mock_dynamodb
def test_lambda_handler():
    db = boto3.resource("dynamodb", region_name="ap-south-1")
    table = db.create_table(
        TableName="aws-cloud-resume-challenge",
        KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
        ProvisionedThroughput={"ReadCapacityUnits": 5, "WriteCapacityUnits": 5},
    )

    table.put_item(Item={"id": "view_count", "views": 1})

    # lambda trigger
    response = lambda_handler(None, None)

    assert response['statusCode'] == 200
    assert response['body'] == '"2"'
    assert table.get_item(Key={'id': 'view_count'})['Item']['views'] == 2