# security group com liberação da porta 22(ssh) e http(80)
resource "aws_security_group" "state_ec2_sg" {
  name        = "humangov-${var.state_name}-ec2-sg"
  description = "Allow traffic on ports 22 and 80"

  # web port
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # troubleshooting port
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # allow cloud9 and ansible connect to instances
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1" # all
    security_groups = ["sg-0b0efb34b82395262"]
  }
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1" # all
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "humangov-${var.state_name}"
  }
}

# criação de instância EC2 para cada estado
resource "aws_instance" "state_ec2" {
  ami           = "ami-007855ac798b5175e"
  instance_type = "t2.micro"
  key_name = "humangov-ec2-key"
  
  # Security group that EC2 will use
  vpc_security_group_ids = [aws_security_group.state_ec2_sg.id]
  
  # Permission that gives access to EC2 instance to manipulate S3 and DynamoDB
  iam_instance_profile = aws_iam_instance_profile.s3_dynamodb_full_access_instance_profile.name

  #----- provisioners -----
  
  # necessary for ansible to execute commands without asking permission on first time
  provisioner "local-exec" {
    command = "sleep 30; ssh-keyscan ${self.private_ip} >> ~/.ssh/known_hosts"
  }
  
  # add a host on ansible configuration file hosts automatically
  provisioner "local-exec" {
    command = "echo ${var.state_name} id=${self.id} ansible_host=${self.private_ip} ansible_user=ubuntu us_state=${var.state_name} aws_region=${var.region} aws_s3_bucket=${aws_s3_bucket.state_s3.bucket} aws_dynamodb_table=${aws_dynamodb_table.state_dynamodb.name} >> /etc/ansible/hosts"
  }
  
  # when destroying the resources, wipe from ansible host configuration this EC2 host
  provisioner "local-exec"{
    command = "sed -i '/${self.id}/d' /etc/ansible/hosts"
    when = destroy
  }
  
  
   tags = {
    Name = "humangov-${var.state_name}"
  }
  
  
}

# criação de tabela no dynamodb para cada estado
resource "aws_dynamodb_table" "state_dynamodb" {
  name           = "humangov-${var.state_name}-dynamodb"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "humangov-${var.state_name}"
  }
}

# geração de string randômica com provider local para utilização no nome do bucket s3
resource "random_string" "bucket_suffix" {
  length  = 4
  special = false
  upper = false
}

# criação de um bucket s3 para cada estado
resource "aws_s3_bucket" "state_s3" {
  bucket = "humangov-${var.state_name}-s3-${random_string.bucket_suffix.result}"

  tags = {
    Name = "humangov-${var.state_name}"
  }
}

#----------- Creating a role, attaching 2 policies and attaching role to EC2 -----------

# creating a ROLE and defining which entity can assume it in the future
resource "aws_iam_role" "s3_dynamodb_full_access_role" {
  name = "humangov-${var.state_name}-s3_dynamodb_full_access_role"
  
  # with this, only EC2 instance can assume this role in the future
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal":{
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = "humangov-${var.state_name}"
  }

}

# These two blocks attaches a POLICY on the previous created ROLE
# So the role now has two policies associated
resource "aws_iam_role_policy_attachment" "s3_full_access_role_policy_attachment" {
  role = aws_iam_role.s3_dynamodb_full_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "dynamodb_full_access_role_policy_attachment" {
  role = aws_iam_role.s3_dynamodb_full_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}


# Attaching the role into the EC2 instance through "instance profile"
resource "aws_iam_instance_profile" "s3_dynamodb_full_access_instance_profile" {
  name = "humangov-${var.state_name}-s3_dynamodb_full_access_instance_profile"
  role = aws_iam_role.s3_dynamodb_full_access_role.name
  
  tags = {
    Name = "humangov-${var.state_name}"
  }
  
}

#----------- With this, EC2 instances can make actions on S3 and DynamoDB -----------