output "web_public_ip" { value = aws_eip.web_eip.public_ip }
output "monitoring_public_ip" { value = aws_instance.monitoring.public_ip }
output "web_private_ip" { value = aws_instance.web.private_ip }
output "db_private_ip" { value = aws_instance.db.private_ip }
output "private_zone_name" { value = aws_route53_zone.private.name }
output "private_records" {
  value = {
    web        = aws_route53_record.web_a.name
    db         = aws_route53_record.db_a.name
    monitoring = aws_route53_record.monitoring_a.name
  }
}