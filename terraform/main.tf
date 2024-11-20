# Step 1: Configure the Terraform backend with S3
terraform {
  backend "s3" {
    bucket  = "ashok-tf"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

# Step 2: AWS Provider Configuration
provider "aws" {
  region = "us-east-1"
}

# Step 3: Create a New VPC
resource "aws_vpc" "new_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "new-vpc"
  }
}

# Step 4: Create Public Subnets
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnet" {
  count                = 2
  vpc_id               = aws_vpc.new_vpc.id
  cidr_block           = cidrsubnet(aws_vpc.new_vpc.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone    = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

# Step 5: Security Group for ECS
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.new_vpc.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-sg"
  }
}

# Step 6: ECS Cluster
resource "aws_ecs_cluster" "ashok_hotel_cluster" {
  name = "ashok_hotel-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "ashok_hotel-cluster"
  }
}

# Step 7: ECS Task Definition
resource "aws_ecs_task_definition" "ashok_hotel_task_definition" {
  family                   = "ashok_hotel"
  execution_role_arn       = "arn:aws:iam::863518440386:role/ecsTaskExecutionRole"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "3072"

  runtime_platform {
    cpu_architecture    = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = <<DEFINITION
[
  {
    "name": "ashok_hotel",
    "image": "863518440386.dkr.ecr.us-east-1.amazonaws.com/ashok_hotel:latest",
    "cpu": 0,
    "portMappings": [
      {
        "name": "ashok_hotel-3000-tcp",
        "containerPort": 3000,
        "hostPort": 3000,
        "protocol": "tcp",
        "appProtocol": "http"
      }
    ],
    "essential": true,
    "environment": [],
    "environmentFiles": [],
    "mountPoints": [],
    "volumesFrom": [],
    "ulimits": [],
    "systemControls": []
  }
]
DEFINITION
}

# Step 8: ECS Service
resource "aws_ecs_service" "ashok_hotel_service" {
  name            = "ashok_hotel-service"
  cluster         = aws_ecs_cluster.ashok_hotel_cluster.id
  task_definition = aws_ecs_task_definition.ashok_hotel_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public_subnet[*].id
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  deployment_controller {
    type = "ECS"
  }

  tags = {
    Name = "ashok_hotel-service"
  }
}
