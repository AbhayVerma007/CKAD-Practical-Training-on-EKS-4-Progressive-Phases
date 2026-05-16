# VPC Module

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1"

  # This sets the base name, which the module uses to auto-name subnets!
  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  
  # 4 private subnets
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
  
  # 2 public subnets
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # FIX 1: Ensures Load Balancers get public IPs
  map_public_ip_on_launch = true

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Kubernetes specific tags for AWS Load Balancer Controller
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  # FIX 2: Removed the overriding "Name" tag so subnets auto-generate proper names
  tags = {
    Environment = var.environment
  }
}

# EKS Cluster Module

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.16"

  cluster_name    = "${var.cluster_name}-${var.environment}"
  cluster_version = var.cluster_version
  
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)  # ✅ FIX: Include both

#Modern AWS EKS clusters require a specific add-on called the Amazon EBS CSI Driver to communicate with AWS and create EBS volumes

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Cluster security group

  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_security_group_id   = module.eks.node_security_group_id
    }
  }

  # Node group configuration

  eks_managed_node_groups = {
    main = {
      name            = "main-node-group"
      use_name_prefix = true
      
      instance_types = [var.node_instance_type]
      
      desired_size = var.node_group_desired_size
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size

      capacity_type  = "ON_DEMAND"
      disk_size      = 25

      # IAM role policies

      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy      = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy           = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonEBSCSIDriverPolicy           = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      tags = {
        Name = "${var.cluster_name}-node"
      }
    }
  }

  tags = {
    Name = "${var.cluster_name}-eks"
  }
}

# ECR Repository

resource "aws_ecr_repository" "app" {
  name                 = "${var.cluster_name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.cluster_name}-ecr"
  }
}