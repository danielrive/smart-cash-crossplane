#### Netwotking Creation

module "networking" {
  source             = "./modules/networking"
  project_name       = var.project_name
  region             = var.region
  environment        = var.environment
  cidr               = "10.120.0.0/16"
  availability_zones = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1], data.aws_availability_zones.available.names[2]]
  private_subnets    = ["10.120.0.0/22", "10.120.64.0/22", "10.120.128.0/22"]
  db_subnets         = ["10.120.4.0/22", "10.120.68.0/22", "10.120.132.0/22"]
  public_subnets     = ["10.120.32.0/22","10.120.96.0/22", "10.120.160.0/22"]
  enable_nat_gw      = false
  create_nat_gw      = false
  single_nat_gw      = false
}


### KMS Key to encrypt kubernetes resources
module "kms_key_eks" {
  source              = "./modules/kms"
  region              = var.region
  environment         = var.environment
  project_name        = var.project_name
  name                = "eks"
  key_policy          = data.aws_iam_policy_document.kms_key_policy_encrypt_logs.json
  enable_key_rotation = true
}

### Create ACM Cert for argocd

resource "aws_acm_certificate" "argo_cert" {
  domain_name       = "argo.smcashcrossplane.rootdr.info"
  validation_method = "DNS"

  tags = {
    Environment = var.environment
  }
  lifecycle {
    create_before_destroy = true
  }
}

## Certificate Validation


resource "aws_route53_record" "argo_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.argo_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.rootdr.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.argo_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.argo_cert_validation : record.fqdn]
}



# ##########################
# # EKS Cluster
# ##########################

module "eks_cluster" {
  source                       = "./modules/eks"
  environment                  = var.environment
  region                       = var.region
  project_name                 = var.project_name
  cluster_version              = "1.26"
  subnet_ids                   = module.networking.main.public_subnets
  retention_control_plane_logs = 7
  instance_type_worker_nodes   = var.environment == "develop" ? ["t3.medium"] : ["t3.medium"]
  AMI_for_worker_nodes         = "AL2_x86_64"
  desired_nodes                = 1
  max_instances_node_group     = 1
  min_instances_node_group     = 1
  private_endpoint_api         = true
  public_endpoint_api          = true
  kms_arn                      = module.kms_key_eks.kms_arn
  userRoleARN                  = "arn:aws:iam::${data.aws_caller_identity.id_account.id}:role/user-mgnt-eks-cluster"
}
