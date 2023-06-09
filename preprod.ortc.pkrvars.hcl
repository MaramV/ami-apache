role_arn        = "arn:aws:iam::615828586605:role/Jelecos_Admin"
vpc_tag_name    = "ecom-PreProd-vpc" // vpc on prod
subnet_tag_name = "packer-subnet" // subnet on prod
s3_bucket        = "615828586605-ec2-resources"
ssh_user        = "ec2-user"
ssh_keyfile    = "~/Documents/keys/otc-preprod-key-west-2.pem" // local location of key
ec2_type       = "t3a.small"
region         = "us-west-2"
environment     = "preprod"