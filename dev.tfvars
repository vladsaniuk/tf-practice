public_subnets = {
  us-east-1a = "10.0.0.0/19"
  us-east-1b = "10.0.32.0/19"
  us-east-1c = "10.0.64.0/19"
  us-east-1d = "10.0.96.0/19"
}

private_subnets = {
  us-east-1a = "10.0.128.0/19"
  us-east-1b = "10.0.160.0/19"
  us-east-1c = "10.0.192.0/19"
  us-east-1d = "10.0.224.0/19"
}

cluster_users = [
  {ARN = "arn:aws:iam::250705831128:root", username = "admin"}
]

disk_size      = 40
instance_types = ["t3.medium"]
desired_size   = 1
max_size       = 2
min_size       = 1

secrets = ["mysql_root_password", "mysql_password", "mysql_replication_password"]