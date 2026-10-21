# ==================== ECR (private Docker image registry) ====================
resource "aws_ecr_repository" "app" {
  name                 = "learningsteps-api"
  image_tag_mutability = "IMMUTABLE" # lets us re-push the tag "unlatest"
  force_delete         = true        # lets `terraform destroy` delete the repo even if it holds images

  image_scanning_configuration {
    scan_on_push = true # hint: true or false? We want AWS to scan every pushed image for vulnerabilities
  }

  encryption_configuration {
    encryption_type = "AES256" # images encrypted at rest
  }

  tags = var.common_tags
}

output "ecr_repository_url" {
  description = "Where to push the Docker image"
  value       = aws_ecr_repository.app.repository_url # hint: which attribute holds the repository URL? Check the Registry page, "Attribute Reference"
}