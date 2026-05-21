{
  description = "Development shell for Rewrap Revived";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

  outputs = { nixpkgs, ... }:
    let
      systems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      formatter = forAllSystems
        (system: let pkgs = import nixpkgs { inherit system; }; in pkgs.nixfmt);

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [ dotnet-sdk_6 nodejs_21 ];
            shellHook = ''
              cat <<EOF

              Rewrap Revived Dev Shell

                  dotnet $(dotnet --version)
                  node.js $(node --version)
                  npm $(npm --version)
              EOF
              ./do
            '';
          };
        });
    };
}
