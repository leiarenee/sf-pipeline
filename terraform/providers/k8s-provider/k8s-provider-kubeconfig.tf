
variable "cluster_id" {
  description = "Name of the cluster"
  type        = string
  default     = ""
}

data "aws_eks_cluster" "cluster" {
  count = var.cluster_id != "" ? 1 : 0
  name  = var.cluster_id
}

provider "kubernetes" {
  config_path = "${path.module}/.kubeconfig"
  config_context =  element(concat(data.aws_eks_cluster.cluster[*].arn, tolist([""])), 0)
}
