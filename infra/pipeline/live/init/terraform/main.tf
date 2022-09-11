resource "random_pet" "this" {
  length = 2
}

output "lineage" {
  value = random_pet.this.id
}

