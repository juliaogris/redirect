package main

import (
	"log"
	"net/http"
)

func redirect(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "https://meet.google.com/uoh-tmka-hhj", http.StatusSeeOther)
}

func main() {
	if err := http.ListenAndServe(":8080", http.HandlerFunc(redirect)); err != nil {
		log.Fatalln(err)
	}
}
