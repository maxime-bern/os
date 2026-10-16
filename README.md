# os &nbsp; [![bluebuild build badge](https://github.com/maxime-bern/os/actions/workflows/build.yml/badge.svg)](https://github.com/maxime-bern/os/actions/workflows/build.yml)

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

After setup, it is recommended you update this README to describe your custom image.

## Installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/maxime-bern/os:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/maxime-bern/os:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

### Dotfiles

Stow is installed in the image; dotfiles are not. Clone and install them manually as your user in a running Plasma session:

```bash
git clone --branch chore/migrate-to-stow https://gitlab.com/maximebern/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Update them manually with `git pull && ./install.sh`. Use the default branch instead once the Stow migration is merged.

### Wayland session

The Kinoite base keeps KDE, and `profiles/de/niri-session.yml` (pulled by `profiles/de/kde.yml`) adds niri and Noctalia next to it: `niri` (with `xwayland-satellite` for X11 apps), `noctalia`, `xdg-desktop-portal-gtk` and `xdg-desktop-portal-gnome` for file pickers and screencasting, `gnome-keyring` for the Secret portal, `upower` and `ddcutil` for Noctalia's battery and external-brightness widgets. `files/system/usr/share/xdg-desktop-portal/niri-portals.conf` selects those portals and pins `FileChooser` to GTK so no Nautilus is needed. Noctalia draws the bar, launcher, notifications, lock screen and wallpaper; its config lives in the dotfiles repo (`~/.config/niri/config.kdl` and `~/.config/noctalia/config.toml`).

Pick the `niri` session in SDDM after rebasing. Portal screencasting only works from `niri-session`, i.e. from SDDM or the `niri-session` script.

### BlueBuild switch

Build and switch to the local recipe with the helper script. It uses a graphical Polkit prompt for BlueBuild's privileged operation:

```bash
./switch.sh
```

Pass BlueBuild switch options directly, for example `./switch.sh --reboot`. Set `RECIPE` to build
the alternative recipe: `RECIPE=recipe-noctalia.yml ./switch.sh`.

## Images

| Recipe | Image | Base |
| --- | --- | --- |
| `recipes/recipe.yml` | `ghcr.io/maxime-bern/os` | Kinoite (KDE Plasma) + niri/Noctalia |
| `recipes/recipe-noctalia.yml` | `ghcr.io/maxime-bern/os-noctalia` | Atomic base, niri + Noctalia + Noctalia greeter |

### Layout

Three layers, one direction: a recipe says which machine it is, a profile says which
capabilities that machine has, a module installs one thing.

```
recipe-work-os.yml   profiles/de/niri.yml + shell, dev, system, browsers, secrets, vpn, codecs,
                     media-playback, chat, work + signing
recipes/profiles/    one file per capability: de/niri, de/niri-session, de/kde, shell, dev,
                     virtualization, system, browsers, secrets, vpn, codecs, capture, gaming,
                     media-playback, chat, media, apps, work. A profile may include another profile (dev pulls
                     virtualization).
recipes/modules/     one file per piece of software, with the wiring it needs: its repo, its
                     packages, its shipped files, its systemd unit, its script, its flatpak.
```
Work and personal differ only in the recipe's list: `recipe-work-os.yml` includes
`media-playback` (VLC, Spotify), `chat` (Discord) and `work` (gcloud, OnlyOffice, FileZilla), but
no capture, gaming, video editing or torrent apps. The personal recipes include these through
`media` and `apps`, alongside `capture` and `gaming`.

### os-noctalia

Same profiles as `os` except the `de/` one (`de/niri.yml` instead of `de/kde.yml`, so no KDE
tweaks), on the minimal Fedora Atomic base instead of Kinoite. Note that the KDE framework
packages `shell.yml` pulls in are dependencies of the dotfiles installer, not of KDE: they are in
every image. The base already ships
pipewire/wireplumber, NetworkManager, polkit, accountsservice, flatpak, the xdg portals, upower
and Mesa, so only the desktop itself has to be added.

Login flow: `profiles/de/niri-session.yml` adds niri, Noctalia, `xwayland-satellite`,
gnome-keyring, ddcutil and the GTK/GNOME portals; `profiles/de/niri.yml` adds the GTK
file manager this base does not ship (Kinoite keeps Dolphin instead) plus greetd and
`noctalia-greeter` (from the community Terra repo, absent from Fedora) and enables
`greetd.service`, which is aliased to `display-manager.service`. `files/greeter/` holds the
greetd `config.toml` pointing at `/usr/bin/noctalia-greeter-session` running as the `greetd`
user, and a `tmpfiles.d` drop-in for the greeter state dir `/var/lib/noctalia-greeter`. The
greeter draws its own wlroots compositor, so it works on a TTY before any session starts.

The greeter lists the sessions it finds in `/usr/share/wayland-sessions`, here only niri. No
`greeter.toml` is shipped: the built-in defaults apply until one is written (a declarative one
belongs in `/var/lib/noctalia-greeter/greeter.toml`, owned by `greetd`).

Rebase with the same commands as above, replacing `os` with `os-noctalia`.

If the greeter does not come up, keep a TTY available and check `systemctl status greetd`,
`journalctl -u greetd -b` and `ausearch -m avc -ts recent` (SELinux is the usual suspect with a
greeter built outside of Fedora).

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/how-to/generate-iso/#_top). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/maxime-bern/os
```
