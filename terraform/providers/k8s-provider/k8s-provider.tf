provider "kubernetes" {
  host                   = try(aws_eks_cluster.this[0].endpoint, "")
  cluster_ca_certificate = base64decode(try(aws_eks_cluster.this[0].certificate_authority[0].data, ""))

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", try(aws_eks_cluster.this[0].id, "")]
  }
}