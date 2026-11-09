package main

import (
	"crypto/tls"
	"net/http"
	"time"
)

func bad(u string) {
	// ruleid: go-http-default-client-no-timeout
	_, _ = http.Get(u)
	// ruleid: go-http-default-client-no-timeout
	_, _ = http.Head(u)
	// ruleid: go-http-default-client-no-timeout
	_, _ = http.DefaultClient.Get(u)

	// ruleid: go-tls-insecure-skip-verify
	_ = &tls.Config{InsecureSkipVerify: true}

	// ruleid: go-tls-min-version-too-low
	_ = &tls.Config{MinVersion: tls.VersionTLS10}
}

func good(u string) {
	c := &http.Client{Timeout: 10 * time.Second}
	// ok: go-http-default-client-no-timeout
	_, _ = c.Get(u)

	// ok: go-tls-insecure-skip-verify
	_ = &tls.Config{InsecureSkipVerify: false}

	// ok: go-tls-min-version-too-low
	_ = &tls.Config{MinVersion: tls.VersionTLS12}
}
