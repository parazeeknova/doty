# Lennette private overlay

The `lennette-private` input in the root flake points to a published Lennette
revision, with its compositor dependencies pinned in `flake.lock`. Building
this integration does not need a local Lennette or Hyprland source checkout.

The Hyprland module imports the input's NixOS and Home Manager modules. The
application itself is installed separately; its executable defaults to
`${config.home.homeDirectory}/.local/bin/lennette`. Set
`programs.lennettePrivateOverlay.executable` in the Home Manager configuration
if it is installed elsewhere.

For a setup you can copy into another NixOS flake, see the
[Lennette installation guide](https://github.com/parazeeknova/lennette/tree/main/packaging/hyprland#nixos-and-home-manager-setup).
It includes the reusable input and module imports, without doty's host or user
configuration.

After switching to this configuration, save your work and log out of Hyprland,
then log back in. A rebuild or reload cannot replace the running compositor.
Run `lennette-private-user --check` in the new session before launching Lennette.
The module disables compositor plugins and routes the desktop launcher and
shortcuts through the protected launcher.
