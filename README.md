# fastly-websocket-poc

## Deploy

First run the following commands

```bash
brew bundle --file Brewfile
ngrok start --all --config ngrok.yml
```

This will start ngrok and expose `localhost:9001` and `localhost:9002` to the internet.  Then you need to update the local variables in `main.tf` to the outputted ngrok urls.

Now in two separate tabs of your terminal run the following commands:

```bash
echo-server --port 9001 --type http
echo-server --port 9002 --type websocket
```

This starts two echo servers on addresses `localhost:9001` and `localhost:9002`.  The first is a simple http server that returns the request headers.  The second is a websocket server that echos back the message sent to it.

The fastly service is deployed using terraform. The terraform script is `main.tf`. To deploy the service, run the following commands:

```bash
tfenv use
terraform init
terraform apply -auto-approve \ 
    -var "tld=jmoney.dev" \ 
    -var "subdomain=echo" \ 
    -var websocket_backend=$(curl --silent "http://127.0.0.1:4040/api/tunnels" | jq -r '.tunnels[] | select(.name == "websocket") | .public_url') \ 
    -var request_backend=$(curl --silent "http://127.0.0.1:4040/api/tunnels" | jq -r '.tunnels[] | select(.name == "request") | .public_url')
```

This does a terraform apply with the state generated locally. This is currently using cloudflare as the DNS provider.  Please set the `tld` terraform variable to tld you own and have access too in cloudflare.  Cloudflare was used for demo purposes it can be replaced with any DNS provider supported by terraform such as AWS Route53.

### Providers used

* [Cloudflare](https://registry.terraform.io/providers/cloudflare/cloudflare/4.11.0/docs)
* [Fastly](https://registry.terraform.io/providers/fastly/fastly/5.2.2/docs)

## Test

Once deployed you can run the following test to see this in action:

```bash
curl --silent "https://echo.jmoney.dev/http"
websocat "wss://echo.jmoney.dev/websocket"
```

After the first command you'll see an echoed response as well as some logging in the echo-server terminal tab.  After the second command, you'll need to type some text and hit enter and then you'll see the an echoed response as well as some logging in the echo-server terminal tab.  This shows that the websocket connection is being upgraded and the websocket server is receiving the message.

## Cleanup

When testing is complete do not forget to tear it all down. To do so run the following command:

```bash
tfenv use
terraform init
terraform destroy -auto-approve \ 
    -var "tld=jmoney.dev" \ 
    -var "subdomain=echo" \ 
    -var websocket_backend=$(curl --silent "http://127.0.0.1:4040/api/tunnels" | jq -r '.tunnels[] | select(.name == "websocket") | .public_url') \ 
    -var request_backend=$(curl --silent "http://127.0.0.1:4040/api/tunnels" | jq -r '.tunnels[] | select(.name == "request") | .public_url')
```
