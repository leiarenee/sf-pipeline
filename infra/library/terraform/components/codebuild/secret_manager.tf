
data "aws_secretsmanager_secret" "secrets" {
  arn = var.secret_manager_name_for_repo
  provider = aws.secrets
}

data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.secrets.id
  provider = aws.secrets
}

locals {
  secret_string = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)
  repo_user=local.secret_string["user"]
  repo_token=local.secret_string["token"]

}
