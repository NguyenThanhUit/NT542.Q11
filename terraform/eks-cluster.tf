# Tạo KMS Key
resource "aws_kms_key" "eks_secrets" {
  description         = "KMS CMK for EKS Secrets Encryption"
  enable_key_rotation = true
}

resource "aws_kms_alias" "eks_secrets_alias" {
  name          = "alias/eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.19.1"

  cluster_name    = local.cluster_name
  cluster_version = "1.30"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true


  cluster_encryption_config = [
    {
      resources = ["secrets"]
      provider  = {
        key_arn = aws_kms_key.eks_secrets.arn
      }
    }
  ]

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

  }
  
}