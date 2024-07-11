output "db_cluster_identifier" {
  value = aws_rds_cluster.main.cluster_identifier
}


output "db_secret_arn" {
  value = aws_rds_cluster.main.master_user_secret[0].secret_arn
}

output "db_reader_endpoint" {
  value = aws_rds_cluster.main.reader_endpoint
}

output "db_writer_endpoint" {
  value = aws_rds_cluster.main.endpoint
}

output "db_name" {
  value = aws_rds_cluster.main.database_name
}
