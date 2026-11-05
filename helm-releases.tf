resource "helm_release" "portfolio" {

  name = "portfolio"

  chart = "${path.module}/portfolio-chart"

  namespace = "portfolio-helm"

  create_namespace = true

  values = [
    file("${path.module}/portfolio-chart/values.yaml")
  ]

  wait = true

  timeout = 600

  atomic = true

}