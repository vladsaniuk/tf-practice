data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_iam_role" "karpenter_node_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          "Service" : "ec2.amazonaws.com"
        }
      }
    ]
  })
  description = "Karpenter Node role for ${var.cluster_name}"
  name        = "KarpenterNodeRole-${var.cluster_name}"
  path        = "/"
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "worker_node_policy_to_role" {
  role       = aws_iam_role.karpenter_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_policy_to_role" {
  role       = aws_iam_role.karpenter_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "cni_policy_to_role" {
  role       = aws_iam_role.karpenter_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ssm_policy_to_role" {
  role       = aws_iam_role.karpenter_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "karpenter_controller_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.eks_oidc.oidc.issuer_url}" # cluster.identity.oidc.issuer
        }
        Condition = {
          "StringEquals" : {
            "${var.eks_oidc.oidc.issuer_url}:aud": "sts.amazonaws.com",
            "${var.eks_oidc.oidc.issuer_url}:sub": "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })
  description = "Karpenter Controller role for ${var.cluster_name}"
  name        = "KarpenterControllerRole-${var.cluster_name}"
  path        = "/"
  tags        = var.tags
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
            "ec2:DescribeImages",
            "ec2:RunInstances",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeInstanceTypeOfferings",
            "ec2:DescribeAvailabilityZones",
            "ec2:DeleteLaunchTemplate",
            "ec2:CreateTags",
            "ec2:CreateLaunchTemplate",
            "ec2:CreateFleet",
            "ec2:DescribeSpotPriceHistory",
            "pricing:GetProducts"
        ]
        Effect   = "Allow"
        Resource = "*"
        Sid = "Karpenter"
      },
      {
        Action = [
            "ec2:TerminateInstances"
        ]
        Effect = "Allow"
        Resource = "*"
        Sid = "ConditionalEC2Termination"
      },
      {
        Action = [
            "iam:PassRole"
        ]
        Effect = "Allow"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.karpenter_node_role.name}"
        Sid = "PassNodeIAMRole"
      },
      {
        Action = [
            "eks:DescribeCluster"
        ]
        Effect = "Allow"
        Resource = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
        Sid = "EKSClusterEndpointLookup"
      }
    ]
  })
  description = "Karpenter Controller role for ${var.cluster_name}"
  name        = "KarpenterNodeRole-${var.cluster_name}"
  path        = "/"
  tags        = var.tags
}

resource "aws_iam_policy_attachment" "karpenter_controller_policy_to_role" {
  name = "karpenter-controller-policy-to-role-attachment"
  roles = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}
