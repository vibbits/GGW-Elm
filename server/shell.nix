let
  pkgs = import <nixpkgs> { };

  my-packages = pkgs.python39Full.withPackages (p: with p; [
    fastapi
    hypercorn
    pytest
  ]);
in
pkgs.mkShell {
  buildInputs = [
    my-packages
  ];
}
