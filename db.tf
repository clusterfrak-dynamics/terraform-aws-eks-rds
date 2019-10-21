resource "random_string" "db_root_password" {
  count   = var.db_password == "" ? 1 : 0
  length  = 16
  special = false
}

resource "aws_security_group" "db" {
  name        = "db-${var.db_identifier}-${var.env}"
  description = "Security group for db ${var.db_identifier}-${var.env}"
  vpc_id      = var.aws["vpc_id"]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.db_tags
}

resource "aws_security_group_rule" "db-eks" {
  description              = "Allow worker Kubelets and pods to communicate with ${var.db_identifier}-${var.env} DB"
  from_port                = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = data.terraform_remote_state.eks.outputs.eks-node-sg
  to_port                  = var.db_port
  type                     = "ingress"
}

resource "aws_security_group_rule" "db-bastion-eks" {
  count                    = data.terraform_remote_state.eks.outputs.bastion-sg == "" ? 0 : 1
  description              = "Allow worker Kubelets and pods to communicate with ${var.db_identifier}-${var.env} DB"
  from_port                = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = data.terraform_remote_state.eks.outputs.bastion-sg
  to_port                  = var.db_port
  type                     = "ingress"
}

resource "aws_security_group_rule" "db-bastion" {
  count                    = var.db_remote_security_group_id == "" ? 0 : 1
  description              = "Allow worker Kubelets and pods to communicate with ${var.db_identifier}-${var.env} DB"
  from_port                = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = var.db_remote_security_group_id
  to_port                  = var.db_port
  type                     = "ingress"
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> v2.0"

  identifier = "${var.db_identifier}-${var.env}"

  engine               = var.db_engine
  engine_version       = var.db_engine_version
  family               = var.db_family
  major_engine_version = var.db_major_engine_version

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_encrypted = var.db_storage_encrypted
  storage_type      = var.db_storage_type

  name     = var.db_name
  username = var.db_username
  password = var.db_password == "" ? join(",", random_string.db_root_password.*.result) : var.db_password
  port     = var.db_port

  vpc_security_group_ids = [aws_security_group.db.id]

  maintenance_window = var.db_maintenance_window
  backup_window      = var.db_backup_window

  backup_retention_period = var.db_backup_retention_period

  tags = var.db_tags

  enabled_cloudwatch_logs_exports = var.db_enable_cloudwatch_logs_exports

  subnet_ids = data.aws_subnet_ids.private.ids

  final_snapshot_identifier = "${var.db_identifier}-${var.env}-final-snapshot"

  deletion_protection = var.db_deletion_protection

  multi_az = var.db_multi_az
}

resource "kubernetes_secret" "db_secret" {
  count = length(var.inject_secret_into_ns)

  metadata {
    name      = "db-${var.db_identifier}-${var.env}"
    namespace = var.inject_secret_into_ns[count.index]
  }

  data = {
    DB_USERNAME = module.db.this_db_instance_username
    DB_NAME     = module.db.this_db_instance_name
    DB_PASSWORD = var.db_password == "" ? random_string.db_root_password[0].result : var.db_password
    DB_ENDPOINT = module.db.this_db_instance_endpoint
    DB_ADDRESS  = module.db.this_db_instance_address
    DB_PORT     = module.db.this_db_instance_port
  }
}

output "db_instance_address" {
  value = module.db.this_db_instance_address
}

output "db_instance_port" {
  value = module.db.this_db_instance_port
}

output "db_instance_endpoint" {
  value = module.db.this_db_instance_endpoint
}

output "db_instance_password" {
  value     = module.db.this_db_instance_password
  sensitive = true
}
