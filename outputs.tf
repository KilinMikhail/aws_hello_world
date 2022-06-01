output "url" {
  description = "URL for hello world"

  value = join("", [
    aws_api_gateway_deployment.hello_world_deployment.invoke_url,
    aws_api_gateway_resource.hello_world_resource.path
  ])
}
