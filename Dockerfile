# Containerized, pinned build for the Rewrap Revived VS Code extension.
# Produces a .vsix without installing any build tooling on the host.
#
#   Build + export the vsix to ./out :
#     docker build --target export --output type=local,dest=./out .
#
#   (Optional) build just the toolchain+extension image for inspection:
#     docker build --target build -t rewrap-build .
#
# Everything that can be pinned is pinned (base image digest, Node version +
# checksum, lockfile-driven npm ci, Fable version from .config/dotnet-tools.json).
# Dependencies are fetched in earlier RUN layers; the actual compile + package
# step runs with `--network=none`, so a compromised build script cannot reach
# the network while turning source into the shipped artifact.

# .NET SDK 6 (matches flake.nix), pinned by digest. To refresh after an audit:
#   docker buildx imagetools inspect mcr.microsoft.com/dotnet/sdk:6.0
FROM mcr.microsoft.com/dotnet/sdk:6.0@sha256:c8fdd06e430de9f4ddd066b475ea350d771f341b77dd5ff4c2fafa748e3f2ef2 AS build

# --- Node 21.7.3, installed from the official tarball with a verified checksum.
# (apt repos drift; a pinned tarball + sha256 is reproducible.) ---
ARG TARGETARCH
ARG NODE_VERSION=21.7.3
ARG NODE_SHA256_amd64=19e17a77e59044de169cd19be3f3bccae686982fba022f9634421b44724ee90c
ARG NODE_SHA256_arm64=d48a76d02c5940a6dc0738bc0af22551d15cb58b30a5ddddb54fe6e00021f3c1
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils python3 \
    && rm -rf /var/lib/apt/lists/* \
    && case "$TARGETARCH" in \
         amd64) NODE_ARCH=x64; NODE_SHA256="$NODE_SHA256_amd64" ;; \
         arm64) NODE_ARCH=arm64; NODE_SHA256="$NODE_SHA256_arm64" ;; \
         *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
       esac \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
    && echo "${NODE_SHA256}  node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" | sha256sum -c - \
    && tar -xJf "node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" -C /usr/local --strip-components=1 \
    && rm "node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
    && node --version && npm --version

WORKDIR /src
COPY . .

# --- Dependency fetch (network ON). Lockfiles are committed; npm ci installs
# exactly what they pin and fails on any drift, unlike npm install. ---
RUN npm ci --prefix vscode \
    && npm ci

# Restore .NET deps + the pinned Fable tool (version from .config/dotnet-tools.json).
# Restoring the test project also restores the referenced core project, which
# creates .obj/.net/core/project.assets.json -- the marker `./do` uses to skip
# restoring again during the offline build below.
# --locked-mode: fail if the resolved graph differs from the committed
# packages.*.lock.json (which carry SHA-512 contentHash per package), so NuGet
# deps -- direct and transitive -- cannot silently drift.
RUN dotnet tool restore \
    && dotnet restore core/Core.Test.fsproj --locked-mode

# --- Build + package (network OFF). All inputs are present from the layers
# above, so `./do package` compiles core (Fable -> Parcel), bundles the
# extension (Parcel), and packs the vsix (vsce) with no network access. ---
RUN --network=none python3 ./do --no-nix package

# Final stage: a scratch image whose only content is the produced vsix,
# so `--output type=local` writes nothing but the vsix to the host.
FROM scratch AS export
COPY --from=build /src/.obj/*.vsix /
