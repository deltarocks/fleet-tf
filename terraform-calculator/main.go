package main

import "fmt"
import "golang.org/x/mod/sumdb/dirhash"
import "flag"
import "path"
import "path/filepath"
import "os"
import "log"

var providerPath string
var sourceAddress string
var version string
var packageDir string
func init() {
	flag.StringVar(&providerPath, "provider-path", "", "Path to provider installation directory")
	flag.StringVar(&sourceAddress, "source-address", "", "Source address")
	flag.StringVar(&version, "version", "", "Provider version")
	flag.StringVar(&packageDir, "package-dir", "", "Package directory")
}

func assertDirectory(msg string, path string) {
	stat, err := os.Stat(path)
	if err != nil {
		log.Fatal(msg, err)
	}
	if !stat.IsDir() {
		log.Fatal(msg, path)
	}
}

// There is command in go docs which is supposed to return the same result as this function...
// It doesn't for me, so this code is written in golang D:
func main() {
	flag.Parse()
	if packageDir == "" {
		if providerPath == "" {
			log.Fatal("-provider-path is not set")
		}
		if sourceAddress == "" {
			log.Fatal("-source-address is not set")
		}
		if version == "" {
			log.Fatal("-version is not set")
		}
		providers := path.Join(providerPath, "libexec", "terraform-providers")
		assertDirectory("expected providers directory (is this a terraform package?): ", providers)
		packageVersionless := path.Join(providers, sourceAddress)
		assertDirectory("expected package without version directory (invalid source address?): ", packageVersionless)
		packageDir = path.Join(packageVersionless, version)
	}
	assertDirectory("expected package directory (invalid version?): ", packageDir)

	archs, err := os.ReadDir(packageDir)
	if err != nil {
		log.Fatal(err)
	}
	for _, file := range archs {
		arch := file.Name()
		archDir := path.Join(packageDir, arch)
		resolvedArchDir, err := filepath.EvalSymlinks(archDir)
		s, err := dirhash.HashDir(resolvedArchDir, "", dirhash.Hash1)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Print("\"", s, "\", # ", arch, "\n")
	}
}
