output "vpc_id" {
  value = aws_vpc.main.id
}


output "public_subnet_ids" {
  value = aws_subnet.public.*.id
}

output "db_private_subnet_ids" {
  value = aws_subnet.private_db.*.id
}