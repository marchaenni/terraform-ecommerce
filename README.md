# Terraform Ecommerce (AWS)
Automatisiert die ursprüngliche Aufgabe:
- VPC, Subnets, NAT, IGW, Routing
- SGs (Web, DB), NACLs (allow all)
- EC2 Web (Nginx+Gunicorn) & DB (MariaDB)
- Route53 Private Zone (webshop.tbz)

**Fixes:** keine Portkollision, sauberes Cloud-Init, Basic-Auth, DB-Zugriff nur Web.
