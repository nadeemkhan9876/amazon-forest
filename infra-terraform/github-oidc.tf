# ==================== GitHub Actions access (OIDC) ====================

# Who am I? (gives us the account number without typing it)
data "aws_caller_identity" "current" {}

# The GitHub provider: "AWS trusts badges signed by GitHub". We create it ourselves.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"] # hint: the audience GitHub puts on its badge. It is the same text as the "aud" condition in the role below
  tags           = var.common_tags
}

# The role that GitHub pipeline runs will "put on"
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # hint 1: only runs from MY repository on the main branch may use this role
          # format: repo:<github-user>/<repo-name>:ref:refs/heads/main
          "token.actions.githubusercontent.com:sub" = "repo:nadeemkhan9876/amazon-forest:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = var.common_tags
}

# What the role may do: push images to OUR repository, and look at OUR cluster
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # login to ECR; this action cannot be limited to one repository
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # push images, but ONLY into our own repository
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = aws_ecr_repository.app.arn # hint 2: which attribute holds the repository ARN?
      },
      {
        # needed later so kubectl can find the cluster
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}-cluster"
        # hint 3: which attribute of aws_caller_identity holds the account number?
      },
    ]
  })
}

output "github_actions_role_arn" {
  description = "The role ARN that the GitHub workflow will use"
  value       = aws_iam_role.github_actions.arn # hint 4: which attribute holds the ARN?
}