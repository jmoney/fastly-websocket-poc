# fastly-websocket-poc

## Deploy

To start run `ngrok start --all --config ngrok.yml`. This will start ngrok and expose `localhost:9001` and `localhost:9002` to the internet.  Then you need to update the local variables in `main.tf` to the outputted ngrok urls.

The fastly service is deployed using terraform. The terraform script is `main.tf`. To deploy the service, run the following commands:

```bash
op run -- terraform apply -auto-approve
```

This does a terraform apply with the state generated locally.  `op run` is the 1password cli client which exposes a few environment variables used for authentication of the providers.  This is currently using cloudflare as the DNS provider and my personal TLD, `jmoney.dev`.  You will need to update the `main.tf` file to use your own DNS provider and TLD.
