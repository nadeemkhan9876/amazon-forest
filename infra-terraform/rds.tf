# ==================== RDS (managed PostgreSQL) ====================
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id] # PRIVATE subnets only

  tags = {
    Name = "${var.project_name}-db-subnets"
  }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "learningsteps"
  username = var.db_username
  password = var.db_password # which variable holds the password?

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id] # the database's firewall

  publicly_accessible = false # true or false?
  storage_encrypted   = true
  skip_final_snapshot = true # lab only

  tags = var.common_tags
}

output "rds_endpoint" {
  description = "Database address (host:port)"
  value       = aws_db_instance.main.endpoint # check Attribute Reference on the Registry page
}