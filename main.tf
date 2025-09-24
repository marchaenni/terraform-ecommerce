########################################
# NETWORK
########################################

data "aws_ami" "ubuntu_jammy" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

locals {
  web_host = "webserver"
  db_host  = "dbserver"
  monitoring_host = "monitoring"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "ecommerce-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "ecommerce-igw" })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.aws_az
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "ecommerce-public" })
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.aws_az
  tags              = merge(var.tags, { Name = "ecommerce-private" })
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "ecommerce-nat-eip" })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  tags          = merge(var.tags, { Name = "ecommerce-nat" })
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "ecommerce-public-rt" })
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "ecommerce-private-rt" })
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

########################################
# SECURITY GROUPS + NACLs
########################################

resource "aws_security_group" "sg_webshop" {
  name        = "sg_webshop"
  description = "Allow SSH/HTTP from anywhere"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "sg_webshop" })

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_db" {
  name        = "sg_db"
  description = "DB access only from web SG; SSH from VPC"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "sg_db" })

  ingress {
    description     = "MySQL/MariaDB from web SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_webshop.id]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_monitoring" {
  name        = "sg_monitoring"
  description = "Allow access to Grafana/Prometheus"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "sg_monitoring" })

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Alertmanager/Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Additional monitoring apps"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "web_node_exporter" {
  description              = "Allow Prometheus metrics scraping from monitoring host"
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_webshop.id
  source_security_group_id = aws_security_group.sg_monitoring.id
}

resource "aws_network_acl" "public_nacl" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = [aws_subnet.public.id]
  tags       = merge(var.tags, { Name = "nacl-public-allowall" })
}

resource "aws_network_acl_rule" "public_ingress_all" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "public_egress_all" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = [aws_subnet.private.id]
  tags       = merge(var.tags, { Name = "nacl-private-allowall" })
}

resource "aws_network_acl_rule" "private_ingress_all" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "private_egress_all" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

########################################
# KEY PAIR (gleicher Key für Web & DB)
########################################

resource "aws_key_pair" "lab_rsa" {
  key_name   = "ecommerce-key"
  public_key = var.ssh_public_key
  tags       = merge(var.tags, { Name = "ecommerce-key" })
}

########################################
# EC2: DB (Private), WEB (Public + EIP)
########################################

resource "aws_instance" "db" {
  ami                         = data.aws_ami.ubuntu_jammy.id
  instance_type               = var.instance_type_db
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.sg_db.id]
  associate_public_ip_address = false
  key_name                    = aws_key_pair.lab_rsa.key_name

  user_data                   = templatefile("${path.module}/userdata/db_cloud_init.yaml.tftpl", {
    db_name      = var.db_name
    db_user      = var.db_user
    db_password  = var.db_password
    sql_dump_url = var.sql_dump_url
  })
  # >>> NEU: ersetzt Instanz automatisch, wenn sich user_data ändert
  user_data_replace_on_change = true

  tags = merge(var.tags, { Name = "ecommerce-db" })
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu_jammy.id
  instance_type               = var.instance_type_web
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.sg_webshop.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.lab_rsa.key_name

  user_data                   = templatefile("${path.module}/userdata/web_cloud_init.yaml.tftpl", {
    app_zip_url         = var.app_zip_url
    wsgi_module         = var.wsgi_module
    basic_auth_user     = var.basic_auth_user
    basic_auth_password = var.basic_auth_password
    db_host_fqdn        = "${local.db_host}.${var.domain_name}"
    db_name             = var.db_name
    db_user             = var.db_user
    db_password         = var.db_password
  })
  # >>> NEU: ersetzt Instanz automatisch, wenn sich user_data ändert
  user_data_replace_on_change = true

  tags = merge(var.tags, { Name = "ecommerce-web" })

  depends_on = [aws_instance.db]
}

resource "aws_eip" "web_eip" {
  instance = aws_instance.web.id
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "ecommerce-web-eip" })
}

resource "aws_instance" "monitoring" {
  ami                         = data.aws_ami.ubuntu_jammy.id
  instance_type               = var.instance_type_monitoring
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.sg_monitoring.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.lab_rsa.key_name

  user_data = templatefile("${path.module}/userdata/monitoring_cloud_init.yaml.tftpl", {
    stack_dir     = "/home/ubuntu/m169-scripts/KN05_B"
    stack_parent  = "/home/ubuntu/m169-scripts"
    web_host_fqdn = "${local.web_host}.${var.domain_name}"
  })

  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(var.tags, { Name = "ecommerce-monitoring" })

  depends_on = [aws_instance.web]
}

########################################
# ROUTE53 PRIVATE ZONE + RECORDS
########################################

resource "aws_route53_zone" "private" {
  name = var.domain_name
  vpc { vpc_id = aws_vpc.this.id }
  comment = "Private Hosted Zone for Ecommerce"
}

resource "aws_route53_record" "web_a" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "webserver.${var.domain_name}"
  type    = "A"
  ttl     = 30
  records = [aws_instance.web.private_ip]
}

resource "aws_route53_record" "db_a" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "dbserver.${var.domain_name}"
  type    = "A"
  ttl     = 30
  records = [aws_instance.db.private_ip]
}

resource "aws_route53_record" "monitoring_a" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "${local.monitoring_host}.${var.domain_name}"
  type    = "A"
  ttl     = 30
  records = [aws_instance.monitoring.private_ip]
}
