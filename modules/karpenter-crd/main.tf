# Configure provisioner CRD
resource "kubernetes_manifest" "provisioner_default" {
  computed_fields = ["spec.requirements"]
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
            "t"
          ]
        },
        {
          "key"      = "karpenter.k8s.aws/instance-generation"
          "operator" = "Gt"
          "values" = [
            "2"
          ]
        },
        {
          "key"      = "karpenter.k8s.aws/instance-size"
          "operator" = "In"
          "values" = [
            "small",
            "medium"
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
