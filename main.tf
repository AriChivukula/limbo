terraform {
  backend "s3" {}
}

variable "S3_ID" {}

variable "S3_SECRET" {}

variable "S3_REGION" {}

variable "NAME" {
  default = "limbo"
}

variable "DOMAIN" {
  default = "limbo.chivuku.la"
}

provider "aws" {}

data "aws_vpc" "VPC" {
  tags = {
    Name = "aol"
  }
}

data "aws_subnet_ids" "PUBLIC_SUBNETS" {
  vpc_id = "${data.aws_vpc.VPC.id}"
  tags = {
    Name = "aol"
    Type = "Public"
  }
}

data "aws_subnet_ids" "PRIVATE_SUBNETS" {
  vpc_id = "${data.aws_vpc.VPC.id}"
  tags = {
    Name = "aol"
    Type = "Private"
  }
}

resource "aws_security_group" "SECURITY" {
  name = "${var.NAME}"
  vpc_id = "${data.aws_vpc.VPC.id}"

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

  tags = {
    Name = "${var.NAME}"
  }
}

resource "aws_route53_zone" "ZONE" {
  name = "${var.DOMAIN}."

  tags = {
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
  subnets = ["${data.aws_subnet_ids.PUBLIC_SUBNETS.ids}"]
  security_groups = ["${aws_security_group.SECURITY.id}"]
  
  tags = {
    Name = "${var.NAME}"
  }
}

resource "aws_lb_target_group" "LB_TARGET" {
  name = "${var.NAME}"
  port = 80
  protocol = "HTTP"
  vpc_id = "${data.aws_vpc.VPC.id}"
  target_type = "ip"
  
  health_check {
    path = "/"
    matcher = "200-399"
  }
  
  tags = {
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

resource "aws_lb_listener" "LB_REDIRECT" {
  load_balancer_arn = "${aws_lb.LB.id}"
  port = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port = "443"
      protocol = "HTTPS"
      status_code = "HTTP_301"
    }
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
        "name": "REVISION",
        "value": "${timestamp()}"
      },
      {
        "name": "S3ENABLE",
        "value": "true"
      },
      {
        "name": "S3BUCKET",
        "value": "limbo.chivuku.la"
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
  desired_count = 1
  launch_type = "FARGATE"
  name = "${var.NAME}"
  task_definition = "${aws_ecs_task_definition.TASK.arn}"
  health_check_grace_period_seconds  = 600

  network_configuration {
    subnets = ["${data.aws_subnet_ids.PRIVATE_SUBNETS.ids}"]
    security_groups = ["${aws_security_group.SECURITY.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.LB_TARGET.id}"
    container_name   = "${var.NAME}"
    container_port   = 80
  }
}

resource "aws_s3_bucket_object" "OBJECT" {
  bucket = "${var.DOMAIN}"
  key = "config.yml"
  source = "config.yml"
  etag = "${md5(file("config.yml"))}"
}
