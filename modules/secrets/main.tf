# Use AWS SSM Parameters Store with encryption as secrets manager
resource "aws_ssm_parameter" "parameter" {
  name = var.name
  type = "SecureString"
  tier = "Standard"
  value = "dummyValue"
  tags = tomap(merge({ Name = "${var.name}-${var.env}-env" }, var.tags)) 

  lifecycle {
    ignore_changes = [ value ]
  }
}