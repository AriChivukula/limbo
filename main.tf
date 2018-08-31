terraform {
  backend "s3" {}
}

variable "NAME" {}

variable "DOMAIN" {}

provider "aws" {}

resource "aws_vpc" "ob_vpc" {
  cidr_block = "192.168.0.0/16"

  tags {
    Name = "${var.NAME}"
  }
}

data "aws_availability_zones" "ob_azs" {}

resource "aws_subnet" "ob_subnet_public" {
  count = "${length(data.aws_availability_zones.ob_azs.names)}"
  cidr_block = "${cidrsubnet(aws_vpc.ob_vpc.cidr_block, 8, count.index)}"
  vpc_id = "${aws_vpc.ob_vpc.id}"
  availability_zone = "${data.aws_availability_zones.ob_azs.names[count.index]}"

  tags {
    Name = "${var.NAME}"
    Type = "Public"
  }
}

resource "aws_internet_gateway" "ob_internet" {
  vpc_id = "${aws_vpc.ob_vpc.id}"

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_route_table" "ob_table_public" {
  vpc_id = "${aws_vpc.ob_vpc.id}"

  tags {
    Name = "${var.NAME}"
    Type = "Public"
  }
}

resource "aws_route" "ob_route_iw" {
  route_table_id = "${aws_route_table.ob_table_public.id}"
  gateway_id = "${aws_internet_gateway.ob_internet.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "ob_assoc_public" {
  count = "${length(data.aws_availability_zones.ob_azs.names)}"
  subnet_id = "${element(aws_subnet.ob_subnet_public.*.id, count.index)}"
  route_table_id = "${aws_route_table.ob_table_public.id}"
}

resource "aws_eip" "ob_eip" {
  vpc = true
}

resource "aws_nat_gateway" "ob_nat" {
  allocation_id = "${aws_eip.ob_eip.id}"
  subnet_id = "${aws_subnet.ob_subnet_public.0.id}"
  
  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_subnet" "ob_subnet_private" {
  count = "${length(data.aws_availability_zones.ob_azs.names)}"
  cidr_block = "${cidrsubnet(aws_vpc.ob_vpc.cidr_block, 8, count.index + length(data.aws_availability_zones.ob_azs.names))}"
  vpc_id = "${aws_vpc.ob_vpc.id}"
  availability_zone = "${data.aws_availability_zones.ob_azs.names[count.index]}"

  tags {
    Name = "${var.NAME}"
    Type = "Private"
  }
}

resource "aws_route_table" "ob_table_private" {
  vpc_id = "${aws_vpc.ob_vpc.id}"

  tags {
    Name = "${var.NAME}"
    Type = "Private"
  }
}

resource "aws_route" "ob_route_nat" {
  route_table_id  = "${aws_route_table.ob_table_private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = "${aws_nat_gateway.ob_nat.id}"
}

resource "aws_route_table_association" "ob_assoc_private" {
  count = "${length(data.aws_availability_zones.ob_azs.names)}"
  subnet_id = "${element(aws_subnet.ob_subnet_private.*.id, count.index)}"
  route_table_id = "${aws_route_table.ob_table_private.id}"
}

resource "aws_security_group" "ob_security" {
  name = "${var.NAME}"
  vpc_id = "${aws_vpc.ob_vpc.id}"

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

resource "aws_acm_certificate" "ob_certificate" {
  domain_name = "${var.DOMAIN}"
  subject_alternative_names = ["*.${var.DOMAIN}"]
  validation_method = "DNS"

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_route53_zone" "ob_zone" {
  name = "${var.DOMAIN}."

  tags {
    Name = "${var.NAME}"
  }
}

resource "aws_route53_record" "ob_record" {
  depends_on = [
    "aws_acm_certificate.ob_certificate",
  ]

  name = "${aws_acm_certificate.ob_certificate.domain_validation_options.0.resource_record_name}"
  records = ["${aws_acm_certificate.ob_certificate.domain_validation_options.0.resource_record_value}"]
  ttl = 60
  type = "${aws_acm_certificate.ob_certificate.domain_validation_options.0.resource_record_type}"
  zone_id = "${aws_route53_zone.ob_zone.zone_id}"
}

resource "aws_acm_certificate_validation" "ob_validation" {
  certificate_arn = "${aws_acm_certificate.ob_certificate.arn}"
  validation_record_fqdns = ["${aws_route53_record.ob_record.fqdn}"]
}

resource "aws_iam_role" "ob_iam" {
  name = "${var.NAME}"

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

resource "aws_iam_role_policy_attachment" "ob_permission_lambda" {
  role = "${aws_iam_role.ob_iam.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ob_permission_vpc" {
  role = "${aws_iam_role.ob_iam.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
