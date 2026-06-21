<!-- This part has to be written in HTML, because doing it in markdown puts the content in
a <p>, which adds unwanted margins. It has to be in a table so it can be right-aligned on
GitHub. For GitHub we can't get rid of the border on the td nor make the font smaller as
we want-->
<table class="topright" align="right" style="font-size:90%;width:auto;margin:0;border:none">
<tr style="border:none"><td align="right" style="border:none">
For <a href="https://marketplace.visualstudio.com/items?itemName=dnut.rewrap-revived"><b>VS Code</b></a>,
<a href="https://open-vsx.org/extension/dnut/rewrap-revived"><b>Open VSX</b></a> and
<a href="https://marketplace.visualstudio.com/items?itemName=stkb.Rewrap-18980">
  <b>Visual Studio</b></a>.<br/>
Latest stable version <b>1.16.3</b> / pre-release <b>17.x</b> /
<a href="https://github.com/dnut/rewrap/releases">changelog</a>
</td></tr></table>


<h1 style="font-size: 2.5em">Rewrap Revived</h1>

Rewrap Revived is a Visual Studio and VS Code extension that is used to hard-wrap code 
comments to a configured maximium line length. This is a fork of the unmaintained 
[Rewrap](https://github.com/stkb/Rewrap) extension by Steve Baker 
([@stkb](https://github.com/stkb)).

> **About this fork.** This is a personal, security-vetted fork of
> [dnut/rewrap](https://github.com/dnut/rewrap). It exists so the extension can be
> built from audited source and side-loaded locally, **without** trusting a
> pre-built artifact from a marketplace or pulling build dependencies onto the host
> machine. The functional extension code is unchanged from upstream; the additions
> here are a hardened, reproducible build pipeline:
>
> * A pinned, containerized build ([Dockerfile](Dockerfile)) — base image pinned by
>   digest, Node pinned by version + sha256, npm deps installed via `npm ci` from the
>   committed lockfiles, and the compile/package step run with `--network=none`.
> * A `.dockerignore` that keeps host build artifacts out of the image.
>
> No build or compile tooling (.NET SDK, Node, Fable, vsce) is installed on the host —
> everything runs inside the container, and only the finished `.vsix` is exported.

<br><img src="https://dnut.github.io/Rewrap/images/example.svg" width="700px"/><br/><br/>

The main Rewrap command is: <sn>**Rewrap Comment / Text**</sn>, by default bound to
`Alt+Q`. With the cursor in a comment block, hit this to re-wrap the contents to the
[specified wrapping column](https://dnut.github.io/Rewrap/configuration/#wrapping-column).

## Features

* Re-wrap comment blocks in many languages, with per-language settings.
* Smart handling of contents, including Java-/JS-/XMLDoc tags and code examples.
* Can select lines to wrap or multiple comments/paragraphs at once (even the whole
  document).
* Also works with Markdown documents, LaTeX or any kind of plain text file.

The contents of comments are usually parsed as markdown, so you can use lists, code
samples (which are untouched) etc:

<img src="https://dnut.github.io/Rewrap/images/example1.svg" width="700px"/>

<div class="hideOnDocsSite"><br/><b><a href="https://dnut.github.io/Rewrap/">
See the docs site for more info.</a></b></div>

## Installation (build from source, side-load locally)

This fork is intended to be built from source and installed manually, rather than
pulled from a marketplace. The build runs entirely inside a Docker container, so the
only requirement on the host is Docker.

1. Build the extension and export the `.vsix` to `./out`:

   ```sh
   docker build --target export --output type=local,dest=./out .
   ```

2. Side-load it into VS Code (no marketplace involved):

   ```sh
   code --install-extension out/rewrap-revived-*.vsix
   ```

   Then reload VS Code.

To verify or remove later:

```sh
code --list-extensions | grep rewrap                      # confirm installed (stefano-valentino.rewrap-revived)
code --uninstall-extension stefano-valentino.rewrap-revived # remove
```

This fork uses its own publisher (`stefano-valentino`), so its extension ID is
`stefano-valentino.rewrap-revived` — distinct from the marketplace extension
`dnut.rewrap-revived`. This matters: VS Code keys on the extension ID and will fetch
marketplace metadata (publisher name, ratings, download count) for any ID that matches
a listing, even for a locally side-loaded build. A distinct ID guarantees the installed
extension shows *this* fork's identity and never resolves to the upstream listing. If
you still have the marketplace version installed, remove it with
`code --uninstall-extension dnut.rewrap-revived`.

Side-loaded extensions are **not** auto-updated by VS Code — the installed bytes stay
frozen at exactly what you built until you rebuild and reinstall. This is intentional:
updates only happen when you re-audit and rebuild.

### Refreshing the pins after an audit

The Dockerfile pins the .NET SDK base image by digest. After auditing a newer
toolchain, refresh it with:

```sh
docker buildx imagetools inspect mcr.microsoft.com/dotnet/sdk:6.0
```

and update the `@sha256:...` digest in the [Dockerfile](Dockerfile).

## Security hardening

This fork's goal is a supply-chain-resistant build: the extension you install is
compiled from source you can audit, using a toolchain that cannot silently change
underneath you. The functional extension code is unchanged from upstream — all of the
following are build/packaging changes layered on top.

**Build isolation (host stays clean)**
* The entire toolchain (.NET SDK, Node, Fable, `vsce`, Parcel) runs inside a Docker
  container ([Dockerfile](Dockerfile)). Nothing is installed on the host; only the
  finished `.vsix` is exported via a `FROM scratch` stage.
* [.dockerignore](.dockerignore) keeps host artifacts (e.g. a host `node_modules`)
  out of the image, so the in-container build is clean and reproducible.
* The compile/package step runs with `--network=none`. Dependencies are fetched in
  earlier layers; the step that turns source into the shipped artifact has no network
  access, so a compromised build script cannot exfiltrate or fetch code while building.

**Every dependency pinned and cryptographically locked**
* **npm** (root + `vscode/`): installed with `npm ci` from committed
  `package-lock.json` files (lockfileVersion 2). Every entry — direct and transitive —
  carries an SRI `sha512` integrity hash; `npm ci` fails on any drift.
* **NuGet / .NET**: committed `core/packages.core.lock.json` and
  `core/packages.test.lock.json` lock the full transitive graph with a SHA-512
  `contentHash` per package. Restore runs in `--locked-mode`, failing the build if the
  resolved graph deviates from the lockfiles.
* **Fable tool**: pinned to an exact version in [.config/dotnet-tools.json](.config/dotnet-tools.json).
* **Docker base image**: pinned by `sha256` digest, not a floating tag.
* **Node runtime**: pinned to an exact version and installed from the official tarball
  verified against its `sha256` checksum (per architecture), rather than a
  drift-prone apt repository.

**Manual, audited updates only**
* Side-loaded extensions are not auto-updated by VS Code. The installed bytes stay
  frozen at exactly what you built until you re-audit, rebuild, and reinstall.

**Residual trust notes**
* `npm ci` and `dotnet restore` necessarily run with network access to fetch
  dependencies. The lockfiles and checksums pin *what* is fetched, and `--network=none`
  protects the compile step — but an audit should still cover the dependency tree
  those lockfiles pin, since that code executes during the build.
* The Fable tool's own dependency closure is not lockfile-backed (dotnet local tools
  don't support lockfiles); it is bounded by its pinned version plus the
  digest-pinned SDK image.

## Contributing

To build and test locally, run `./do build` and `./do test`. See the
[contributing guide](https://dnut.github.io/Rewrap/CONTRIBUTING/) for full development workflow
documentation including prerequisites, manual testing, and publishing.
