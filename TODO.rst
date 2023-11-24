======
 TODO
======

2023-11-17 13:15 START

* Doc that App Runner udpates on new ECR image automatically.
* Doc logs for app
* Get S3 name for Docker: aws cloudformation
  describe-stacks --stack-name scale0-dev --query "Stacks[0]"
* Should I build separate ARM (M1) and AMD (AWS) images?
* Should I switch to finch?? Will it help building multiarchitecture builds?
* Do I need the VPC public gateway?
* Do I need the routes, or does that get me to DB and S3?

Can't Do
========

* CANNOT: Set CloudWatch logs to expire in 30 days: can't, no "resource" handle to them.


