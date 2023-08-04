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
op run -- terraform apply -auto-approve
```

This does a terraform apply with the state generated locally.  `op run` is the 1password cli client which exposes a few environment variables used for authentication of the providers.  This is currently using cloudflare as the DNS provider and my personal TLD, `jmoney.dev`.  You will need to update the `main.tf` file to use your own DNS provider and TLD or remove entirely and manage your DNS outside the script.

### Providers used

* [Cloudflare](https://registry.terraform.io/providers/cloudflare/cloudflare/4.11.0/docs)
* [Fastly](https://registry.terraform.io/providers/fastly/fastly/5.2.2/docs)

## Test

Once deployed you can run the following test to see this in action:

```bash
curl --silent "https://echo.jmoney.dev"
websocat "wss://echo.jmoney.dev"
```

After the first command you'll see an echoed response as well as some logging in the echo-server terminal tab.  After the second command, you'll need to type some text and hit enter and then you'll see the an echoed response as well as some logging in the echo-server terminal tab.  This shows that the websocket connection is being upgraded and the websocket server is receiving the message.
