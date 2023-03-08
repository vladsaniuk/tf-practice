# Get AccID
data "aws_caller_identity" "current" {}

# Get region
data "aws_region" "current" {}

# Get public ECR username and token for Karpenter Helm chart 
data "aws_ecrpublic_authorization_token" "token" {}

# Create role for Nodes
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

# Attach node policies
resource "aws_iam_role_policy_attachment" "worker_node_policy_to_role" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_policy_to_role" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "cni_policy_to_role" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ssm_policy_to_role" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create Instance profile for nodes 
resource "aws_iam_instance_profile" "karpenter_node_instance_profile" {
  name = "KarpenterNodeInstanceProfile-${var.cluster_name}"
  role = aws_iam_role.karpenter_node_role.name
  tags = var.tags
}

# Create Controller role
resource "aws_iam_role" "karpenter_controller_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          "Federated" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.eks_oidc.oidc[0].issuer_url}" # cluster.identity.oidc.issuer
        }
        Condition = {
          "StringEquals" : {
            "${var.eks_oidc.oidc[0].issuer_url}:aud" : "sts.amazonaws.com",
            "${var.eks_oidc.oidc[0].issuer_url}:sub" : "system:serviceaccount:karpenter:karpenter"
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
        Sid      = "Karpenter"
      },
      {
        Action = [
          "ec2:TerminateInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
        Sid      = "ConditionalEC2Termination"
      },
      {
        Action = [
          "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.karpenter_node_role.name}"
        Sid      = "PassNodeIAMRole"
      },
      {
        Action = [
          "eks:DescribeCluster"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
        Sid      = "EKSClusterEndpointLookup"
      }
    ]
  })
  description = "Karpenter Controller role for ${var.cluster_name}"
  name        = "KarpenterNodeRole-${var.cluster_name}"
  path        = "/"
  tags        = var.tags
}

resource "aws_iam_policy_attachment" "karpenter_controller_policy_to_role" {
  name       = "karpenter-controller-policy-to-role-attachment"
  roles      = [aws_iam_role.karpenter_controller_role.name]
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

# Add configuration to EKS aws-auth configmap
resource "kubernetes_config_map_v1_data" "aws-auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    mapRoles = <<YAML
- groups:
  - system:bootstrappers
  - system:nodes
  rolearn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.karpenter_node_role.name}
  username: system:node:{{EC2PrivateDNSName}}
YAML
  }
}

# Create namespace for Karpenter
resource "kubernetes_namespace" "karpenter_namespace" {
  metadata {
    name = "karpenter"
  }
}

# Install Karpenter with Helm
resource "helm_release" "karpenter" {
  name       = "karpenter-release"
  namespace  = kubernetes_namespace.karpenter_namespace.metadata[0].name
  repository = "oci://public.ecr.aws/karpenter/karpenter"
  chart      = "karpenter"
  version    = "v0.25.0"

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter_node_instance_profile.name
  }

  set {
    name  = "settings.aws.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.annotations.\"eks\\.amazonaws\\.com/role-arn\""
    value = aws_iam_role.karpenter_controller_role.arn
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "0.25"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "256M"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "0.5"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "512M"
  }

  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms.matchExpressions.key"
    value = "eks.amazonaws.com/nodegroup"
  }

  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms.matchExpressions.operator"
    value = "In"
  }

  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms.matchExpressions.values"
    value = var.node_group.node_group_name
  }
}

# Add CRD 
resource "kubernetes_manifest" "sh_provisioners" {
  manifest = yamldecode(file("./modules/karpenter/sh_provisioners.yaml"))
}

# Add CRD
resource "kubernetes_manifest" "aws_awsnodetemplates" {
  manifest = yamldecode(file("./modules/karpenter/aws_awsnodetemplates.yaml"))
}

# Configure provisioner CRD
resource "kubernetes_manifest" "provisioner_default" {
  manifest = {
    "apiVersion" = "karpenter.sh/v1alpha5"
    "kind"       = "Provisioner"
    "metadata" = {
      "name" = "default"
    }
    "spec" = {
      "limits" = {
        "resources" = {
          "cpu" = 2
        }
      }
      "providerRef" = {
        "name" = "default"
      }
      "requirements" = [
        {
          "key"      = "karpenter.k8s.aws/instance-category"
          "operator" = "In"
          "values" = [
            "t",
          ]
        },
        {
          "key"      = "karpenter.k8s.aws/instance-generation"
          "operator" = "Gt"
          "values" = [
            "2",
          ]
        },
        {
          "key"      = "karpenter.k8s.aws/instance-size"
          "operator" = "In"
          "values" = [
            "small",
            "medium",
          ]
        },
        {
          "key"      = "karpenter.k8s.aws/capacity-type"
          "operator" = "In"
          "values" = [
            "spot",
          ]
        },
      ]
    }
  }
}

resource "kubernetes_manifest" "awsnodetemplate_default" {
  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1alpha1"
    "kind"       = "AWSNodeTemplate"
    "metadata" = {
      "name" = "default"
    }
    "spec" = {
      "securityGroupSelector" = {
        "karpenter.sh/discovery" = "${var.cluster_name}"
      }
      "subnetSelector" = {
        "karpenter.sh/discovery" = "${var.cluster_name}"
      }
    }
  }
}
