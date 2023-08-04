terraform {
  required_providers {
    fastly = {
      source  = "fastly/fastly"
      version = "= 5.2.2"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
    }
  }
}

resource "fastly_service_vcl" "websocket" {
  name = "fastly-websocket-demo"

  domain {
    name    = "ws-poc.jmoney.dev"
  }

  condition {
    name = "websocket"
    statement = "req.http.Upgrade == \"websocket\""
    type = "REQUEST"
  }

  condition {
    name = "not_websocket"
    statement = "req.http.Upgrade != \"websocket\""
    type = "REQUEST"
  }

  # Fastly requires that shielding is disabled for websocket requests
  snippet {
    name = "disable_shielding_if_websocket"
    content = "set var.fastly_req_do_shield = (req.http.Upgrade != \"websocket\");"
    type = "recv"
    priority = 1
  }

  # The proper location for the websocker upgrade is AFTER the Fastly RECV macro that does the backend selection
  # Fastly does not have a way to do this, so we have to do it manually
  vcl {
    name = "service"
    main = true
    content = file("service.vcl")
  }

  backend {
    name = "ws_backend"
    address = "https://b31a-70-121-110-22.ngrok-free.app"
    request_condition = "websocket"
    ssl_check_cert = false
    port = 443
    use_ssl = true
    ssl_sni_hostname = "b31a-70-121-110-22.ngrok-free.app"
    override_host = "b31a-70-121-110-22.ngrok-free.app"
  }

backend {
    name = "non_ws_backend"
    address = "https://34b1-70-121-110-22.ngrok-free.app"
    request_condition = "not_websocket"
    ssl_check_cert = false
    port = 443
    use_ssl = true
    ssl_sni_hostname = "34b1-70-121-110-22.ngrok-free.app"
    override_host = "34b1-70-121-110-22.ngrok-free.app"
  }

  product_enablement {
    websockets = true
  }

  # Disable caching because websocket connections are not cacheable
  cache_setting {
    name = "disable_caching"
    action = "pass"
  }

  force_destroy = true
}

resource "cloudflare_record" "example" {
  zone_id = var.cloudflare_zone_id
  name    = "ws-poc.jmoney.dev"
  value   = "192.0.2.1"
  type    = "d.sni.global.fastly.net"
}