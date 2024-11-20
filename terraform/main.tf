# Step 2: Configure the Terraform backend with S3
terraform {
  backend "s3" {
    bucket = "ashok-tf"  # Use the same bucket name
    key    = "terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# Step 3: VPC Data Source
data "aws_vpc" "default" {
  default = true
}

# Step 4: Default Subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Default Security Group (get the default security group for the default VPC)
data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Step 5: ECS Cluster
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

# Step 6: ECS Task Definition
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

# Step 7: ECS Service
resource "aws_ecs_service" "ashok_hotel_service" {
  name            = "ashok_hotel-service"
  cluster         = aws_ecs_cluster.ashok_hotel_cluster.id
  task_definition = aws_ecs_task_definition.ashok_hotel_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups = [data.aws_security_group.default.id]
    assign_public_ip = true  # Only for public subnets
  }

  deployment_controller {
    type = "ECS"
  }

  tags = {
    Name = "ashok_hotel-service"
  }
}
