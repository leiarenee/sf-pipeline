output "input_data" {
  value = local.appConfig
}

output "output_data" {
  value = {
    for yaml, conf in module.k8s_yaml_tf.output :
      yaml => {
        for key,value in conf :
          key => value
          if value != null
      }
  }
}


