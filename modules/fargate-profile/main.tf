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

# Create IAM policy for logging
data "aws_iam_policy_document" "fargate_logging_policy" {
  statement {
    sid = "FargateLoggingPolicy"

    actions = [
      "logs:CreateLogStream",
			"logs:CreateLogGroup",
			"logs:DescribeLogStreams",
			"logs:PutLogEvents"
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "fargate_logging_policy_attachment" {
  role       = aws_iam_role.fargate_role.name
  policy_arn = data.aws_iam_policy_document.fargate_logging_policy
}

# Create namespace for Fargate logging
resource "kubernetes_namespace" "aws-observability" {
  metadata {
    name = "aws-observability"
    labels = {
      aws-observability = "enabled"
    }
  }
}

# Create configmap with configuration for Fargate logging
resource "kubernetes_config_map_v1" "aws-logging" {
  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace.aws-observability.metadata[0].name
  }
  data = {
    flb_log_cw = "false"
    filters.conf = <<YAML
[FILTER]
    Name parser
    Match *
    Key_name log
    Parser crio
[FILTER]
    Name kubernetes
    Match kube.*
    Merge_Log On
    Keep_Log Off
    Buffer_Size 0
    Kube_Meta_Cache_TTL 300s
YAML
    output.conf = <<YAML
[OUTPUT]
    Name cloudwatch_logs
    Match   kube.*
    region ${data.aws_region.current}
    log_group_name my-logs
    log_stream_prefix from-fluent-bit-
    log_retention_days 60
    auto_create_group true
YAML
    parsers.conf = <<YAML
[PARSER]
    Name crio
    Format Regex
    Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>P|F) (?<log>.*)$
    Time_Key    time
    Time_Format %Y-%m-%dT%H:%M:%S.%L%z
YAML
  }
}