resource "aws_iam_role" "cluster_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          "Service" : "eks.amazonaws.com"
        }
      }
    ]
  })
  description = "EKS cluster role for ${var.env} env"
  name        = "EKS-cluster-role-${var.env}-env"
  path        = "/"
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "default_cluster_policy_to_role" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn
  vpc_config {
    endpoint_public_access = true
    subnet_ids             = var.private_subnets_ids # Reference resource from other module
  }
  tags    = var.tags
  version = "1.24"
  depends_on = [
    aws_iam_role_policy_attachment.default_cluster_policy_to_role
  ]
}

# Enable EKS OIDC provider

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.eks.identity.0.oidc.0.issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity.0.oidc.0.issuer
  tags            = tomap(merge({ Name = "EKS-OIDC-provider-${var.env}-env" }, var.tags))
}
