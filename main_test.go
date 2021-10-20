package main

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/matryer/is"
)

func TestServer(t *testing.T) {
	is := is.New(t)
	s := httptest.NewServer(http.HandlerFunc(redirect))
	defer s.Close()

	res, err := http.Get(s.URL)
	is.NoErr(err)

	is.Equal(http.StatusOK, res.StatusCode)
	b, err := io.ReadAll(res.Body)
	is.NoErr(err)
	is.True(strings.Contains(string(b), "<!doctype html>"))
}
