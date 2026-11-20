# thumbplan.date

The website and installer for [thumb](https://github.com/mattroyer/thumb). It's a plain static site with no build step:

| File | What it is |
|---|---|
| `index.html` | The homepage |
| `install.sh` | The installer behind `curl -fsSL https://thumbplan.date/install.sh \| sh` |
| `_headers` | Cloudflare headers: serves `install.sh` as plain text, with a short cache |

## How the installer works

It detects the OS and CPU, downloads `thumb_<os>_<arch>.tar.gz` and `checksums.txt` from the latest release of `mattroyer/thumb` on GitHub, verifies the SHA-256 checksum, and installs the binary. It picks the folder in this order: wherever `thumb` already is, then `$THUMB_INSTALL_DIR`, then `/usr/local/bin` if it's writable without sudo, then `~/.local/bin`. Downloads made with curl don't get macOS's quarantine flag, so there's no Gatekeeper prompt.

Options: `THUMB_VERSION=v0.2.0` pins a release, and `THUMB_INSTALL_DIR=~/bin` picks the folder.

It only works once `mattroyer/thumb` has at least one release with version-free file names (thumb's `.goreleaser.yaml` sets that up).

## Deploying on Cloudflare

1. In the Cloudflare dashboard, go to **Workers & Pages** and create an application from this GitHub repo using **Pages**.
2. Build settings: no framework, leave the build command empty, and set the output directory to `/`.
3. Once it deploys, open the project's **Custom domains** tab and add `thumbplan.date`. Because the domain is already on Cloudflare, it sets up DNS and HTTPS for you.

Every push to `main` redeploys the site.

## Testing the installer locally

Point it at a folder of release files instead of GitHub:

```
python3 -m http.server 8765 --directory path/to/release-files &
THUMB_DOWNLOAD_BASE=http://127.0.0.1:8765 THUMB_INSTALL_DIR=/tmp/thumb-test sh install.sh
```
