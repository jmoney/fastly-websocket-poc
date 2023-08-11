terraform {
  required_providers {
    fastly = {
      source  = "fastly/fastly"
      version = "= 5.2.2"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.11.0"
    }
  }
}

provider "cloudflare" {}

provider  "fastly" {}

variable "tld" {
  description = "The top level domain to use for the demo"
}

variable "subdomain" {
  description = "The subdomain to use for the demo, ex: echo"
}

variable "websocket_backend" {
  description = "The backend to use for websocket requests"
}

variable "request_backend" {
  description = "The backend to use for non-websocket requests"
}

variable "type" {
  description = "The type of fastly service to deploy: vcl or compute"
  default = "vcl"
  validation {
    condition = can(regex("vcl|compute", var.type))
    error_message = "type must be either vcl or compute"
  }
}

locals {
  echo_domain = "${var.subdomain}.${var.tld}"

  websocket_backend_domain = trimprefix(var.websocket_backend, "https://")
  request_backend_domain = trimprefix(var.request_backend, "https://")
}

data "cloudflare_zone" "tld" {
  name = var.tld
}

resource "fastly_service_vcl" "echo" {
  count = (var.type == "vcl") ? 1 : 0
  name = "fastly-vcl-websocket-poc"

  domain {
    name = local.echo_domain
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
    name = "main"
    main = true
    content = file("vcl/main.vcl")
  }

  backend {
    name = "ws_backend"
    address = var.websocket_backend
    request_condition = "websocket"
    ssl_check_cert = false
    port = 443
    use_ssl = true
    ssl_sni_hostname = local.websocket_backend_domain
    override_host = local.websocket_backend_domain
  }

backend {
    name = "non_ws_backend"
    address = var.request_backend
    request_condition = "not_websocket"
    ssl_check_cert = false
    port = 443
    use_ssl = true
    ssl_sni_hostname = local.request_backend_domain
    override_host = local.request_backend_domain
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

data "fastly_package_hash" "echo" {
  count = (var.type == "compute") ? 1 : 0

  filename = "./pkg/compute.tar.gz"
}

resource "fastly_service_compute" "echo" {
  count = (var.type == "compute") ? 1 : 0
  name = "fastly-compute-websocket-poc"

  domain {
    name    = local.echo_domain
  }

  package {
    filename         = "./pkg/compute.tar.gz"
    source_code_hash = data.fastly_package_hash.echo[0].hash
  }

    backend {
      name = "ws_backend"
      address = var.websocket_backend
      ssl_check_cert = false
      port = 443
      use_ssl = true
      ssl_sni_hostname = local.websocket_backend_domain
      override_host = local.websocket_backend_domain
  }

  backend {
    name = "nonws_backend"
    address = var.request_backend
    ssl_check_cert = false
    port = 443
    use_ssl = true
    ssl_sni_hostname = local.request_backend_domain
    override_host = local.request_backend_domain
  }

  force_destroy = true
}

resource "fastly_tls_subscription" "tls" {
  domains               = [ local.echo_domain ]
  certificate_authority = "lets-encrypt"
  force_destroy = true
}

resource "cloudflare_record" "tls" {
  depends_on = [ fastly_tls_subscription.tls ]
  for_each = {
    for domain in fastly_tls_subscription.tls.domains : domain => element([
      for obj in fastly_tls_subscription.tls.managed_dns_challenges : obj if obj.record_name == "_acme-challenge.${domain}"
    ], 0)
  }
  zone_id = data.cloudflare_zone.tld.id
  name    = each.value.record_name
  value   = each.value.record_value
  type    = each.value.record_type
  ttl     = 120
}

resource "fastly_tls_subscription_validation" "tls" {
  subscription_id = fastly_tls_subscription.tls.id
  depends_on      = [ cloudflare_record.tls ]
}

resource "cloudflare_record" "echo" {
  depends_on = [ fastly_tls_subscription_validation.tls ]

  zone_id = data.cloudflare_zone.tld.id
  name    = var.subdomain
  value   = "d.sni.global.fastly.net"
  type    = "CNAME"
}
