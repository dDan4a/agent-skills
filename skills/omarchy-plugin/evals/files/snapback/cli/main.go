// snapback keeps copies of files under ~/.local/state/snapback/store/<absolute path>.
package main

import (
	"fmt"
	"os"
	"path/filepath"
)

func store() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "state", "snapback", "store")
}

func save(path string) error {
	abs, err := filepath.Abs(path)
	if err != nil {
		return err
	}
	data, err := os.ReadFile(abs)
	if err != nil {
		return err
	}
	dst := filepath.Join(store(), abs)
	if err := os.MkdirAll(filepath.Dir(dst), 0o700); err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0o600)
}

func main() {
	if len(os.Args) != 3 || os.Args[1] != "save" {
		fmt.Fprintln(os.Stderr, "usage: snapback save <file>")
		os.Exit(2)
	}
	if err := save(os.Args[2]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Println("saved", os.Args[2])
}
