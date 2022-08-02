locals {
    # get json 
    user_data = jsondecode(file("${path.module}/applications.json"))

}

resource kubernetes_deployment deployment {
  for_each     = { for v in local.user_data.applications: v.name => v }
  metadata {
    name = each.value.name
  }
  spec {
    replicas = each.value.replicas
    selector {
      match_labels = {
        app = each.value.name
      }
    }
    template {
      metadata {
        labels = {
          app = each.value.name
        }
      }
      spec {
        container {
            args = [ each.value.args ]
            image = each.value.image
            name = each.value.name
            port {
                container_port = each.value.port
                name = "http"
                protocol = "TCP"
              }
          }
      }
    }
  }
}

resource kubernetes_service service {

  for_each     = { for v in local.user_data.applications: v.name => v }
  depends_on = [kubernetes_deployment.deployment]
  metadata  {
    name = each.value.name
  }
  spec {
    port {
        name = "http"
        port = each.value.port
        protocol = "TCP"
      }
    selector = {
      app = each.value.name
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress" "ingress" {
  for_each     = { for v in local.user_data.applications: v.name => v }
  depends_on = [ kubernetes_deployment.deployment, kubernetes_service.service ]
  metadata {
    labels = {
      app = each.value.name
    }
    name = each.value.name
    annotations = {
      "kubernetes.io/ingress.class": "nginx"
	  "nginx.ingress.kubernetes.io/canary": "true"
	  "nginx.ingress.kubernetes.io/canary-weight": each.value.traffic_weight
    }
  }

  spec {
    rule {
	  host = "canary.example.com"
      http {
        path {
          backend {
            service_name = each.value.name
            service_port = each.value.port
          }
        }
      }
    }
  }
}