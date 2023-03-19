module "network" {
  source          = "./modules/network"
  cluster_name    = local.cluster_name
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  env             = var.env
  tags            = local.tags
}

module "eks" {
  source              = "./modules/eks"
  public_subnets_ids  = module.network.public_subnets_ids
  private_subnets_ids = module.network.private_subnets_ids
  cluster_name        = local.cluster_name
  env                 = var.env
  tags                = local.tags
}

module "node_group" {
  source              = "./modules/node-group"
  cluster_name        = local.cluster_name
  private_subnets_ids = module.network.private_subnets_ids
  disk_size           = var.disk_size
  instance_types      = var.instance_types
  desired_size        = var.desired_size
  max_size            = var.max_size
  min_size            = var.min_size
  cluster_users = var.cluster_users
  env                 = var.env
  tags                = local.tags
}

module "add_ons" {
  source       = "./modules/add-ons"
  cluster_name = local.cluster_name
  env          = var.env
  tags         = local.tags

  depends_on = [
    module.node_group
  ]

}

module "fargate_profile" {
  source              = "./modules/fargate-profile"
  cluster_name        = local.cluster_name
  private_subnets_ids = module.network.private_subnets_ids
  env                 = var.env
  tags                = local.tags
}

module "karpenter" {
  source       = "./modules/karpenter"
  cluster_name = local.cluster_name
  env          = var.env
  eks_oidc     = module.eks.eks_oidc
  node_group   = module.node_group.node_group
  cluster_users = var.cluster_users
  tags         = local.tags

  depends_on = [
    module.eks
  ]

}

locals {
  cluster_name = "${var.env}-eks-cluster"
  tags = {
    Project = "k8s-practice"
    Env     = "${var.env}"
  }
}
