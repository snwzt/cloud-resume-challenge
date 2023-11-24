import json
import boto3

def lambda_handler(event, context):
    db = boto3.resource("dynamodb", region_name="ap-south-1")
    table = db.Table("aws-cloud-resume-challenge")

    response = table.get_item(Key={'id': 'view_count'})
    
    views = response['Item']['views']
    views = views + 1
    
    response =  table.put_item(Item = {
        'id': 'view_count',
        'views': views
    })
    
    return {
        'statusCode': 200,
        'body': json.dumps(str(views))
    }