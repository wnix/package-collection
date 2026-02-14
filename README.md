# packages-and-services

![CI](https://github.com/wnix/packages-and-services/actions/workflows/ci.yml/badge.svg)



Custom Nix packages and NixOS modules for software we use but that is not (yet) available in nixpkgs.

Follows the nixpkgs convention: packages live under `pkgs/<name>/`, modules under `modules/<name>/`.

## Packages

- `seatsurfing-server` -- Go backend + healthcheck
- `seatsurfing-ui` -- Next.js frontend (static export)

## NixOS modules

- `seatsurfing` -- `services.seatsurfing.*`

## Usage

```nix
{
  inputs.wnix.url = "github:wnix/packages";
  inputs.wnix.inputs.nixpkgs.follows = "nixpkgs";
}
```

```bash
nix build .#seatsurfing-server
nix build .#seatsurfing-ui
```

## Binary cache

```
extra-substituters = https://wnix.cachix.org
extra-trusted-public-keys = wnix.cachix.org-1:EjPQ1/a4+2MuoBrTxCy1Uh78jntG41kyLnPprUo/GrU=
```

Add to `nix.settings` in your NixOS config or `~/.config/nix/nix.conf`.

## Adding a new package

1. Create `pkgs/<name>/default.nix`
2. Register it in `flake.nix` under `packages`
3. Optionally add a NixOS module under `modules/<name>/`
4. Add the package to the CI build matrix in `.github/workflows/ci.yml`

## License

Individual packages retain their upstream licenses. The Nix expressions in this repository are MIT-licensed.
