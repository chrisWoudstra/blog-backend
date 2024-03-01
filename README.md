# Blog Backend

This is backend code to support a headless CMS that I'm creating.
The main blog api is a Golang module that lives inside of an AWS Lambda
and is triggered by an API Gateway, which then writes and reads from an
AWS RDS database.