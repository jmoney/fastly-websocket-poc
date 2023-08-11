package main

import (
	"context"
	"fmt"

	"github.com/fastly/compute-sdk-go/fsthttp"
	"github.com/fastly/compute-sdk-go/x/exp/handoff"
)

func main() {
	fsthttp.ServeFunc(func(ctx context.Context, w fsthttp.ResponseWriter, r *fsthttp.Request) {
		if r.Header.Get("Upgrade") == "websocket" {
			err := handoff.Websocket("ws_backend")
			if err != nil {
				w.WriteHeader(fsthttp.StatusBadGateway)
				fmt.Fprintf(w, "%s %s\n", err.Error(), err)
				return
			}
		}

		r.CacheOptions = fsthttp.CacheOptions{
			Pass: true,
		}

		resp, err := r.Send(ctx, "nonws_backend")
		if err != nil {
			w.WriteHeader(fsthttp.StatusBadGateway)
			fmt.Fprintf(w, "%s %s\n", err.Error(), err)
			return
		}
		w.WriteHeader(resp.StatusCode)
		fmt.Fprintf(w, "%s\n", resp.Body)
	})
}
