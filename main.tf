terraform {
  required_providers {
    fastly = {
      source  = "fastly/fastly"
      version = "= 5.2.2"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.0"
    }
  }
}

provider "cloudflare" {}

provider  "fastly" {}

locals {
  websocket_backend_addr = "https://b31a-70-121-110-22.ngrok-free.app"
  nonwebsocket_backend_addr = "https://34b1-70-121-110-22.ngrok-free.app"
  tld = "jmoney.dev"
}

data "cloudflare_zone" "tld" {
  name = local.tld
}

resource "fastly_service_vcl" "websocket" {
  name = "fastly-websocket-demo"

  domain {
    name    = cloudflare_record.websocket.hostname
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
    address = local.websocket_backend_addr
    request_condition = "websocket"
    ssl_check_cert = false
    port = 443
    use_ssl = true
    ssl_sni_hostname = trimprefix(local.websocket_backend_addr, "https://")
    override_host = trimprefix(local.websocket_backend_addr, "https://")
  }

backend {
    name = "non_ws_backend"
    address = local.nonwebsocket_backend_addr
    request_condition = "not_websocket"
    ssl_check_cert = false
    port = 443
    use_ssl = true
    ssl_sni_hostname = trimprefix(local.nonwebsocket_backend_addr, "https://")
    override_host = trimprefix(local.nonwebsocket_backend_addr, "https://")
  }

  # This enables the websocket product feature as a trial. Need to contact support to enable it permanently on paid accounts
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

resource "cloudflare_record" "websocket" {
  zone_id = data.cloudflare_zone.tld.id
  name    = "ws-poc"
  value   = "d.sni.global.fastly.net"
  type    = "CNAME"
}