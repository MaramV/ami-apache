# Commands to build ami
# `packer init apache.pkr.hcl`
# `packer fmt apache.pkr.hcl`
# `packer validate -var-file="{environment}.ortc.pkrvars.hcl" apache.pkr.hcl` - Will validate the template files.
# `packer build -var-file="{environment}.ortc.pkrvars.hcl" apache.pkr.hcl` - Will build the packer template file named `coap.pkr.hcl` and create an AMI using the variables file for configuration

packer {
  required_plugins {
    amazon = {
      version = " >= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "role_arn" {
  type = string
}

variable "vpc_tag_name" {
  type = string
}

variable "subnet_tag_name" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "ssh_keyfile" {
  type = string
}

variable "ec2_type" {
  type = string
}

variable "region" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "environment" {
  type = string
}


locals {
  packerdate     = formatdate("YYYYMMDD", timestamp())
  packerdatetime = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "amazon-ebs" "ortc-apache" {
  #assume_role {
  #  role_arn = "${var.role_arn}"
  #}
  vpc_filter {
    filters = {
      "tag:Name" = "${var.vpc_tag_name}"
    }
  }
  subnet_filter {
    filters = {
      "tag:Name" : "${var.subnet_tag_name}"
    }
    most_free = true
    random    = false
  }
  ami_name                    = "ortc-apache"
  force_deregister            = true
  force_delete_snapshot       = true
  instance_type               = "${var.ec2_type}"
  region                      = "${var.region}"
  associate_public_ip_address = true
  launch_block_device_mappings {
    device_name = "/dev/xvda"
    volume_size = 50
  }
  tags = {
    Name : "ortc-apache"
    Build_Name : "ortc-apache-${local.packerdate}"
    Base_AMI_Name   = "{{ .SourceAMIName }}"
    Build_Timestamp = "${local.packerdatetime}"
    map-migrated    = "d-server-00il1notdel4uu"
    "Budget Code" : "1076.6561.3.9"
    "Cost Center" : "Ecomm"
  }
  temporary_iam_instance_profile_policy_document {
    Statement {
      Action   = ["s3:*"]
      Effect   = "Allow"
      Resource = ["*"]
    }
    Version = "2012-10-17"
  }
  run_tags = {
    AMI_Build_Date = "${local.packerdatetime}",
    environment    = "${var.environment}",
    Project        = "Ecomm Rearch"
    map-migrated   = "d-server-00il1notdel4uu"
    "Budget Code" : "1076.6561.3.9"
    "Cost Center" : "Ecomm"
  }
  run_volume_tags = {
    environment = "${var.environment}",
    Project     = "Ecomm Rearch"
  }
  source_ami_filter {
    filters = {
      name                = "amzn2-ami-kernel-5*"
      architecture        = "x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "${var.ssh_user}"
}

build {
  name = "ortc-apache"
  sources = [
    "source.amazon-ebs.ortc-apache"
  ]

  provisioner "file" {
    sources = [
      "otcweb-apache/conf.d/checkout-weblogic.conf",
      "otcweb-apache/conf.d/f36-weblogic.conf",
      "otcweb-apache/conf.d/mw-weblogic.conf",
      "otcweb-apache/conf.d/otc-weblogic.conf",
      "otcweb-apache/etc/systemd/system/httpd-prod-f36.service",
      "otcweb-apache/etc/systemd/system/httpd-prod-mw.service",
      "otcweb-apache/etc/systemd/system/httpd-prod-otc.service",
      "otcweb-apache/etc/systemd/system/httpd-secureprod-checkout.service",
      "otcweb-apache/httpd-prod-f36.conf",
      "otcweb-apache/httpd-prod-mw.conf",
      "otcweb-apache/httpd-prod-otc.conf",
      "otcweb-apache/httpd-secureprod-checkout.conf",
      "otcweb-apache/redirect-prod-f36.conf",
      "otcweb-apache/redirect-prod-mw.conf",
      "otcweb-apache/redirect-prod-otc.conf",
      "index.html",
      "akamai/sureroute/test-object.html",
      "orientaltrading.com.conf"
    ]
    destination = "/tmp/"
  }
  provisioner "shell" {
    inline = [
      "sudo yum update -y",
      "sudo yum -y install httpd",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo usermod -a -G apache ec2-user",
      "sudo chown -R ec2-user:apache /var/www",
      "sudo chmod 2775 /var/www && find /var/www -type d -exec sudo chmod 2775 {} \\;",
      "find /var/www -type f -exec sudo chmod 0664 {} \\;",
      "sudo yum install -y mod_ssl",
      "sudo systemctl restart httpd.service",
      "sudo yum install -y https://s3.${var.region}.amazonaws.com/amazon-ssm-${var.region}/latest/linux_amd64/amazon-ssm-agent.rpm",
      "sudo mkdir -p /usr/share/collectd/",
      "sudo touch /usr/share/collectd/types.db",
      "sudo yum install -y https://s3.${var.region}.amazonaws.com/amazoncloudwatch-agent-${var.region}/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm",
      "sudo echo '${file("cloudwatch_config.json")}' > /tmp/config.json",
      "sudo cp /tmp/config.json /opt/aws/amazon-cloudwatch-agent/bin/config.json",
      "sudo rm /tmp/config.json",
      "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -s -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json",
      "sudo service amazon-cloudwatch-agent restart",
      "sudo mkdir /var/www/orientaltrading.com",
      "sudo mkdir /var/www/orientaltrading.com/public_html",
      "sudo mkdir /var/log/orientaltrading.com",
      "sudo mkdir /var/log/orientaltrading-services.com",
      "sudo mkdir -p /var/www/orientaltrading.com/public_html/akamai/sureroute/",
      "sudo cp /tmp/index.html /var/www/orientaltrading.com/public_html/index.html",
      "sudo cp /tmp/test-object.html /var/www/orientaltrading.com/public_html/akamai/sureroute/test-object.html",
      "sudo mkdir /var/www/orientaltrading.com/cert",
      "sudo mkdir /home/ec2-user/cert",
      "sudo aws s3 sync s3://${var.s3_bucket}/orientaltrading_cert/ /var/www/orientaltrading.com/cert --exclude '*' --include '*'",

      "sudo yum install ruby -y",
      "sudo yum install wget",
      "sudo yum erase codedeploy-agent -y",
      "cd /home/ec2-user",
      "sudo wget https://aws-codedeploy-us-west-2.s3.us-west-2.amazonaws.com/latest/install",
      "sudo chmod +x ./install",
      "sudo ./install auto",
      "sudo service codedeploy-agent status",
      "sudo service codedeploy-agent start",
      "sudo service codedeploy-agent status",
      #openssl configuration
      "sudo yum install -y make gcc perl-core pcre-devel wget zlib-devel",
      "sudo wget https://www.openssl.org/source/openssl-1.1.1s.tar.gz -P /home/ec2-user",
      "cd /home/ec2-user/",
      "sudo tar -xzvf openssl-1.1.1s.tar.gz",
      "cd openssl-1.1.1s/",
      "sudo ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib no-shared zlib-dynamic",
      "sudo make",
      "sudo make install",
      "sudo sh -c \"echo 'export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64' >> /etc/profile.d/openssl.sh\"",
      #disable server response header
      "sudo sh -c \"echo 'ServerSignature Off' >> /etc/httpd/conf/httpd.conf\"",
      "sudo sh -c \"echo 'ServerTokens Prod' >> /etc/httpd/conf/httpd.conf\"",
      "sudo service httpd restart",
    ]
  }

}
