{
  description = "FStd Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
    devShell.x86_64-linux = let
      system = "x86_64-linux";
      pkgs = import nixpkgs {inherit system;};
    in
      pkgs.mkShell {
        buildInputs = with pkgs; [
          gdb
          zig
          zls
	   sdl3
          ];
        shellHook = ''
          export OPT="Debug"
          function build {
              if [ -z "$1" ]
              then
                zig build -Doptimize=$OPT;
              else
                zig build -Doptimize=$OPT "$1";
              fi
          }
          function check { zig build -Doptimize=$OPT --watch check;}
          zig zen
        '';
      };
  };
}
