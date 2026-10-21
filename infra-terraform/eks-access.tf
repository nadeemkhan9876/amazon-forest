# ==================== Let the GitHub role into the cluster ====================

# 1. Put the role on the cluster's guest list
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.github_actions.arn # hint 1: which attribute holds the role's ARN?
  type          = "STANDARD"

  tags = var.common_tags
}

# 2. Say what it may do there: edit workloads, but only in the "default" namespace
resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.github_actions.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" # hint 2: the built-in policy that allows editing workloads: AmazonEKS + Edit + Policy, written together

  access_scope {
    type       = "namespace" # hint 3: limit the rights to a namespace (not the whole cluster)
    namespaces = ["default"] # hint 4: the namespace where your app runs
  }

  depends_on = [aws_eks_access_entry.github_actions]
}