variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_az" {
  type    = string
  default = "us-east-1a"
}

variable "vpc_cidr" {
  type    = string
  default = "10.11.5.0/24"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.11.5.192/26"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.11.5.0/26"
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "instance_type_web" {
  type    = string
  default = "t2.micro"
}

variable "instance_type_db" {
  type    = string
  default = "t2.micro"
}

variable "domain_name" {
  type    = string
  default = "webshop.tbz"
}

variable "wsgi_module" {
  type    = string
  default = "application:app"
}

variable "app_zip_url" {
  type = string
}

variable "sql_dump_url" {
  type    = string
  default = ""
}

variable "db_name" {
  type    = string
  default = "ecommerce"
}

variable "db_user" {
  type    = string
  default = "shopuser2"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "basic_auth_user" {
  type    = string
  default = "webuser"
}

variable "basic_auth_password" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
  default = {
    Project = "Ecommerce"
    IaC     = "Terraform"
  }
}
