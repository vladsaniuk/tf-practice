data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "fargate_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          "Service" : "eks-fargate-pods.amazonaws.com"
        }
        Condition = {
          "ArnLike" : {
            "aws:SourceArn" : "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:fargateprofile/${var.cluster_name}/*"
          }
        }
      }
    ]
  })
  description = "EKS Fargate role for ${var.env} env"
  name        = "EKS-Fargate-role-${var.env}-env"
  path        = "/"
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "fargate_policy_to_role" {
  role       = aws_iam_role.fargate_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_eks_fargate_profile" "fargate_profile" {
  cluster_name           = var.cluster_name
  fargate_profile_name   = "${var.env}-fargate-profile"
  pod_execution_role_arn = aws_iam_role.fargate_role.arn
  selector {
    namespace = "my-app"
    labels = {
      profile = "fargate"
    }
  }
  subnet_ids = var.private_subnets_ids
  tags       = var.tags
}
