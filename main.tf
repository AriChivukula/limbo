terraform {
  backend "s3" {}
}

variable "NAME" {}

variable "DOMAIN" {}

variable "ROLLBAR_SERVER" {}

variable "SLACK_SIGNING_SECRET" {}

variable "SLACK_CLIENT_ID" {}

variable "SLACK_CLIENT_SECRET" {}

variable "SLACK_REFRESH_TOKEN" {}

variable "S3_ID" {}

variable "S3_SECRET" {}

variable "S3_REGION" {}

provider "aws" {}

resource "aws_vpc" "VPC" {
  cidr_block = "192.168.0.0/16"

  tags {
    Name = "${var.NAME}"
  }
}

data "aws_availability_zones" "AZS" {}

resource "aws_subnet" "PUBLIC_SUBNETS" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  cidr_block = "${cidrsubnet(aws_vpc.VPC.cidr_block, 8, count.index)}"
  vpc_id = "${aws_vpc.VPC.id}"
  availability_zone = "${data.aws_availability_zones.AZS.names[count.index]}"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.NAME}"
    Type = "Public"
  }
}

resource "aws_internet_gateway" "INTERNET_GATEWAY" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_route_table" "PUBLIC_TABLE" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags {
    Name = "${var.NAME}"
    Type = "Public"
  }
}

resource "aws_route" "PUBLIC_ROUTE" {
  route_table_id = "${aws_route_table.PUBLIC_TABLE.id}"
  gateway_id = "${aws_internet_gateway.INTERNET_GATEWAY.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "PUBLIC_ASSOC" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  subnet_id = "${element(aws_subnet.PUBLIC_SUBNETS.*.id, count.index)}"
  route_table_id = "${aws_route_table.PUBLIC_TABLE.id}"
}

resource "aws_eip" "IP" {
  vpc = true
}

resource "aws_nat_gateway" "NAT" {
  allocation_id = "${aws_eip.IP.id}"
  subnet_id = "${aws_subnet.PUBLIC_SUBNETS.0.id}"
  
  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_subnet" "PRIVATE_SUBNETS" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  cidr_block = "${cidrsubnet(aws_vpc.VPC.cidr_block, 8, count.index + length(data.aws_availability_zones.AZS.names))}"
  vpc_id = "${aws_vpc.VPC.id}"
  availability_zone = "${data.aws_availability_zones.AZS.names[count.index]}"

  tags {
    Name = "${var.NAME}"
    Type = "Private"
  }
}

resource "aws_route_table" "PRIVATE_TABLE" {
  vpc_id = "${aws_vpc.VPC.id}"

  tags {
    Name = "${var.NAME}"
    Type = "Private"
  }
}

resource "aws_route" "PRIVATE_ROUTE" {
  route_table_id  = "${aws_route_table.PRIVATE_TABLE.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.NAT.id}"
}

resource "aws_route_table_association" "PRIVATE_ASSOC" {
  count = "${length(data.aws_availability_zones.AZS.names)}"
  subnet_id = "${element(aws_subnet.PRIVATE_SUBNETS.*.id, count.index)}"
  route_table_id = "${aws_route_table.PRIVATE_TABLE.id}"
}

resource "aws_security_group" "SECURITY" {
  name = "${var.NAME}"
  vpc_id = "${aws_vpc.VPC.id}"

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_acm_certificate" "CERTIFICATE" {
  domain_name = "${var.DOMAIN}"
  subject_alternative_names = ["*.${var.DOMAIN}"]
  validation_method = "DNS"

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_route53_zone" "ZONE" {
  name = "${var.DOMAIN}."

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_route53_record" "CERTIFICATE_RECORD" {
  name = "${aws_acm_certificate.CERTIFICATE.domain_validation_options.0.resource_record_name}"
  records = ["${aws_acm_certificate.CERTIFICATE.domain_validation_options.0.resource_record_value}"]
  ttl = 60
  type = "${aws_acm_certificate.CERTIFICATE.domain_validation_options.0.resource_record_type}"
  zone_id = "${aws_route53_zone.ZONE.zone_id}"
}

resource "aws_acm_certificate_validation" "VALIDATION" {
  certificate_arn = "${aws_acm_certificate.CERTIFICATE.arn}"
  validation_record_fqdns = ["${aws_route53_record.CERTIFICATE_RECORD.fqdn}"]
}

resource "aws_iam_role" "IAM_LAMBDA" {
  name = "${var.NAME}-LAMBDA"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "IAM_ROLE_LAMBDA" {
  role = "${aws_iam_role.IAM_LAMBDA.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "IAM_VPC" {
  role = "${aws_iam_role.IAM_LAMBDA.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "LAMBDA" {
  function_name = "${var.NAME}"
  handler = "index.handler"
  role = "${aws_iam_role.IAM_LAMBDA.arn}"
  runtime = "nodejs8.10"
  memory_size = 256
  timeout = 300
  filename = "dynamic.zip"
  publish = true
  source_code_hash = "${base64sha256(file("dynamic.zip"))}"

  environment {
    variables = {
      TF_VAR_ROLLBAR_SERVER = "${var.ROLLBAR_SERVER}"
      TF_VAR_SLACK_SIGNING_SECRET = "${var.SLACK_SIGNING_SECRET}"
      TF_VAR_SLACK_CLIENT_ID = "${var.SLACK_CLIENT_ID}"
      TF_VAR_SLACK_CLIENT_SECRET = "${var.SLACK_CLIENT_SECRET}"
      TF_VAR_SLACK_REFRESH_TOKEN = "${var.SLACK_REFRESH_TOKEN}"
      DEBUG = "*"
    }
  }
  
  vpc_config {
    subnet_ids = ["${aws_subnet.PRIVATE_SUBNETS.*.id}"]
    security_group_ids = ["${aws_security_group.SECURITY.id}"]
  }

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_api_gateway_rest_api" "API" {
  name = "${var.NAME}"
}

resource "aws_api_gateway_resource" "API_GATEWAY" {
  path_part = "{proxy+}"
  parent_id = "${aws_api_gateway_rest_api.API.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.API.id}"
}

resource "aws_api_gateway_method" "API_METHOD" {
  rest_api_id = "${aws_api_gateway_rest_api.API.id}"
  resource_id = "${aws_api_gateway_resource.API_GATEWAY.id}"
  http_method = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "API_INTEGRATION" {
  rest_api_id = "${aws_api_gateway_rest_api.API.id}"
  resource_id = "${aws_api_gateway_method.API_METHOD.resource_id}"
  http_method = "${aws_api_gateway_method.API_METHOD.http_method}"

  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "${replace(aws_lambda_function.LAMBDA.invoke_arn, ":$LATEST", "")}"
}

resource "aws_api_gateway_integration_response" "API_RESPONSE" {
  depends_on = [
    "aws_api_gateway_integration.API_INTEGRATION",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.API.id}"
  resource_id = "${aws_api_gateway_resource.API_GATEWAY.id}"
  http_method = "${aws_api_gateway_method.API_METHOD.http_method}"
  status_code = "200"
}

resource "aws_api_gateway_deployment" "API_DEPLOYMENT" {
  depends_on = [
    "aws_api_gateway_integration_response.API_RESPONSE",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.API.id}"
  stage_name = "PROD"
}

resource "aws_api_gateway_domain_name" "API_DOMAIN" {
  domain_name = "${var.DOMAIN}"

  certificate_arn = "${aws_acm_certificate.CERTIFICATE.arn}"
}

resource "aws_api_gateway_base_path_mapping" "API_MAP" {
  api_id = "${aws_api_gateway_rest_api.API.id}"
  stage_name = "${aws_api_gateway_deployment.API_DEPLOYMENT.stage_name}"
  domain_name = "${aws_api_gateway_domain_name.API_DOMAIN.domain_name}"
}

resource "aws_lambda_permission" "LAMBDA_PERMISSION" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = "${var.NAME}"
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_deployment.API_DEPLOYMENT.execution_arn}/*/*"
}

resource "aws_route53_record" "API_RECORD" {
  name = "${var.DOMAIN}."
  type = "A"
  zone_id = "${aws_route53_zone.ZONE.zone_id}"

  alias {
    evaluate_target_health = false
    name = "${aws_api_gateway_domain_name.API_DOMAIN.cloudfront_domain_name}"
    zone_id = "${aws_api_gateway_domain_name.API_DOMAIN.cloudfront_zone_id}"
  }
}

resource "aws_iam_role" "IAM_ECS" {
  name = "${var.NAME}-ECS"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "IAM_ROLE_ECS" {
  role = "${aws_iam_role.IAM_ECS.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_lb" "LB" {
  name = "${var.NAME}"
  subnets = ["${aws_subnet.PUBLIC_SUBNETS.*.id}"]
  security_groups = ["${aws_security_group.SECURITY.id}"]
  
  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_lb_target_group" "LB_TARGET" {
  name = "${var.NAME}"
  port = 80
  protocol = "HTTP"
  vpc_id = "${aws_vpc.VPC.id}"
  target_type = "ip"
  
  health_check = {
    path = "/"
    matcher = "200-399"
  }
  
  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_lb_listener" "LB_LISTENER" {
  load_balancer_arn = "${aws_lb.LB.id}"
  port = 443
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = "${aws_acm_certificate.CERTIFICATE.arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.LB_TARGET.id}"
    type = "forward"
  }
}

resource "aws_route53_record" "LB_ROUTE" {
  zone_id = "${aws_route53_zone.ZONE.zone_id}"
  name = "docassemble.${var.DOMAIN}."
  type = "A"

  alias {
    name = "${aws_lb.LB.dns_name}"
    zone_id = "${aws_lb.LB.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_ecs_cluster" "CLUSTER" {
  name = "${var.NAME}"
}

resource "aws_ecs_task_definition" "TASK" {
  container_definitions = <<DEFINITION
[
  {
    "name": "${var.NAME}",
    "image": "jhpyle/docassemble:latest",
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "us-east-1",
        "awslogs-group": "${var.NAME}",
        "awslogs-stream-prefix": "main"
      }
    },
    "environment": [
      {
        "name": "S3ENABLE",
        "value": "true"
      },
      {
        "name": "S3BUCKET",
        "value": "${var.DOMAIN}"
      },
      {
        "name": "S3ACCESSKEY",
        "value": "${var.S3_ID}"
      },
      {
        "name": "S3SECRETACCESSKEY",
        "value": "${var.S3_SECRET}"
      },
      {
        "name": "S3REGION",
        "value": "${var.S3_REGION}"
      },
      {
        "name": "EC2",
        "value": "true"
      }
    ]
  }
]
DEFINITION

  cpu = 1024
  execution_role_arn = "${aws_iam_role.IAM_ECS.arn}"
  family = "${var.NAME}"
  memory = 2048
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

resource "aws_ecs_service" "SERVICE" {
  cluster = "${aws_ecs_cluster.CLUSTER.id}"
  desired_count = 2
  launch_type = "FARGATE"
  name = "${var.NAME}"
  task_definition = "${aws_ecs_task_definition.TASK.arn}"
  health_check_grace_period_seconds  = 600

  network_configuration {
    subnets = ["${aws_subnet.PRIVATE_SUBNETS.*.id}"]
    security_groups = ["${aws_security_group.SECURITY.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.LB_TARGET.id}"
    container_name   = "${var.NAME}"
    container_port   = 80
  }
}
