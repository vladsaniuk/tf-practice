# AWS EKS IaC

This repo contain IaC to spin up EKS cluster.
It's logically structured into following modules:
1) network
2) EKS
3) EKS add-ons
4) Node group (EC2)
5) Fargate profile (serverless)
6) Karpenter (auto-scaling for Node group)

To execute complete tf code use, but note that Karpenter module is dependent on EKS module (it use data resource to query cluster details), so it will eventually through you and error, but it can be used for testing / troubleshooting your syntax:

`terraform plan -var-file dev.tfvars`

To execute specific module use:

`terraform plan -var-file dev.tfvars -target="module.network" -out=dev.tfplan`

To apply it:

`terraform apply "dev.tfplan"`

Get kubeconfig:
`aws eks update-kubeconfig --region us-east-1 --name dev-eks-cluster`

To destroy infra, make plan:
`terraform plan -destroy -var-file dev.tfvars -target="module.network" -out=dev-network-destroy.tfplan`

And apply:
`terraform apply "dev-network-destroy.tfplan"`

