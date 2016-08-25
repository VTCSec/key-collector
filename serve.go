package main

import (
	"fmt"
	"log"
	"bytes"
	"os/exec"
	"net/http"
	"rsc.io/letsencrypt"
)

func byFingerprint(w http.ResponseWriter, r *http.Request, fingerprint string) {
	cmd := exec.Command("fetch.sh", fingerprint)
	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	cmd.Stderr = stderr
	cmd.Stdout = stdout

	prefix := "Error encountered trying to fetch your key from the keyserver.\n\nDetails:\n"

	err := cmd.Run()
	if stderr.Len() != 0 {
		http.Error(w, prefix + stderr.String(), http.StatusBadRequest)
		return
	}
	if err != nil {
		http.Error(w, prefix + err.Error(), http.StatusBadRequest)
		return
	}

	pseudoCGI(w, r, "confirm.sh", stdout.String())
}

func pseudoCGI(w http.ResponseWriter, r *http.Request, command string, data string) {
	cmd := exec.Command(command)
	stdin := bytes.NewBufferString(data)
	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	cmd.Stdin = stdin
	cmd.Stdout = stdout
	cmd.Stderr = stderr

	prefix := "Error encountered trying to manipulate your key.\n\nDetails:\n"

	err := cmd.Run()
	if stderr.Len() != 0 {
		http.Error(w, prefix + stderr.String(), http.StatusBadRequest)
		return
	}
	if err != nil {
		http.Error(w, prefix + err.Error(), http.StatusBadRequest)
		return
	}

	fmt.Fprintf(w, stdout.String())
}

func main() {
	http.Handle("/", http.FileServer(http.Dir("static")))

	http.HandleFunc("/by-fingerprint", func(w http.ResponseWriter, r *http.Request) {
		byFingerprint(w, r, r.URL.Query().Get("fp"))
	})

	http.HandleFunc("/by-export", func(w http.ResponseWriter, r *http.Request) {
		pseudoCGI(w, r, "confirm.sh", r.PostFormValue("pubkey"))
	})

	http.HandleFunc("/add", func(w http.ResponseWriter, r *http.Request) {
		pseudoCGI(w, r, "add.sh", r.PostFormValue("pubkey"))
	})

	var m letsencrypt.Manager
	m.SetHosts([]string{"keyparty.vtcsec.org"})
	if err := m.CacheFile("letsencrypt.cache"); err != nil {
		log.Fatal(err)
	}
	log.Fatal(m.Serve())
}
