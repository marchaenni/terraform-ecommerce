aws_region          = "us-east-1"
aws_az              = "us-east-1a"

# Netz & Instanzen
vpc_cidr            = "10.11.5.0/24"
public_subnet_cidr  = "10.11.5.192/26"
private_subnet_cidr = "10.11.5.0/26"
instance_type_web   = "t2.micro"
instance_type_db    = "t2.micro"
instance_type_monitoring = "t3.medium"

# App / Domain / Defaults
app_zip_url         = "https://raw.githubusercontent.com/marchaenni/terraform-ecommerce/main/01_Flask-Python-E-Commerce-Website.zip"
wsgi_module         = "application:app"
domain_name         = "webshop.tbz"
db_name             = "ecommerce"
db_user             = "shopuser"

# Tags
tags                = { Owner = "Marc Haenni", Company = "Marc Haenni AG" }

# --- NICHT mehr hier (kommen aus Secrets) ---
# ssh_public_key
# db_password
# basic_auth_password


