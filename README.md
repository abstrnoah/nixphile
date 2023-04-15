# nixphile

A simple Nix-centric dotfiles manager.

# another dotfiles manager?!

There are already too many "dotfiles managers" so what am I thinking making
another one? See [below](#alternatives) for more details, but basically I
couldn't find something that both follows the [Unix philosophy][unix-philosophy]
and has the features I want. Particularly, I wanted something as dead simple as
[GNU Stow][stow] but as elegant as [Nix][nix] (I had already been using Nix on
[Debian][debian] for some time). GNU Stow is great, but it [suffers from
under-maintenance][stow-undermaint] and I kept hitting up against outstanding
issues. Maybe the biggest motivation for this project, though, was that I wanted
to (1) be able to modularly separate components of dotfiles (e.g. keep GUI and
terminal applications/configuration separate) and (2) be able to easily declare
dependencies between these "modules". I could just write a script to do this,
but I was already using Nix for package management and it was literally designed
to solve exactly my problem. One might be thinking "well, [home-manager] is
already supposed to be the Nix solution to the dotfiles problem"; see below for
my response.

# features

The tool aims to solve (and only solve) these problems:

* Deploy arbitrary dotfiles to the home directory.
* Support modular dotfiles with arbitrary dependencies between them.

Replacing "dotfiles" with "literally any file tree", we reach the following
solution:

* Given a Nix derivation `pkg`, build `pkg` and link the contents of
  `pkg/home/me` to `$HOME` using Stow semantics.
* Provide a simple Nix library to enable the user to obtain Nix derivations from
  directories in their dotfiles repository and declare dependencies between
  them.

To these ends, we aim to provide the following features:

* Support both privileged (user can sudo) and unprivileged (user can't sudo)
  deployment.
* Support "trivial" installation (e.g. just go `sh <(curl
  url/to/intall/script)` with essentially zero prerequisites installed).
* Don't impose a particular structure on dotfiles repository or a particular
  mode of interaction with the dotfiles repository.
* Tap into Nix ecosystem, but don't require the user to use Nix for anything
  beyond running this tool (although unprivileged deployment will naturally rely
  on using Nix packages).

The tool should only be used to _deploy_ dotfiles. Version control, editing,
secrets management, and whatever else the user wants should be handled by other
tools.

# usage

This project provides two [executables](#executables) and a
[Nix library](#nix-library).

The [`install`](#install) shell script attempts to be maximally portable and can
be run as-is in the absence of the rest of this repository.

The [`deploy`](#deploy) shell script also attempts to be portable but does
require a working version of Nix (which the `install` script can install for
you).

Both executables can be run as a flake app like

```sh
nix run 'github:abstrnoah/nixphile#EXECUTABLE' ARGS...
```

although it is not at all required (and it probably makes more sense to run them
as native shell scripts anyway).

See the [next section](#executables) for more about how the executables work.

## example

To be more concrete, suppose Wallace (username `wallace`) has a nice dotfiles
repository at `https://github.com/wallace/dotfiles`. He creates a file named
`flake.nix` in the root of this repository and writes a Nix expression that
provides his dotfiles as one or more "packages"[^2].

Wallace now wants to setup a completely new machine named `gromit` that just has
`curl` installed. Wallace probably wants to run something like

```sh
sh <(curl -L https://raw.githubusercontent.com/abstrnoah/nixphile/main/install) \
    --nix multiuser --dotfiles https://github.com/wallace/dotfiles ~/.dotfiles \
    --deploy gromit
```

This assumes that Wallace has created a Nix derivation named `gromit` in the
`flake.nix` file, with the implication that `gromit` holds the environment
intended for the new machine. Namely, any files located at `/home/me` in the
output of `gromit` will be deployed to Wallace's new `$HOME` directory via
symlink. Since the `muiltiuser` mode is given, Wallace should have root
privileges on `gromit`.

On the other hand, if Wallace is given access to a machine where he doesn't have
root privileges but still wants the comfort of his dotfiles, then he could run

```sh
sh <(curl -L https://raw.githubusercontent.com/abstrnoah/nixphile/main/install) \
    --nix portable --dotfiles https://github.com/wallace/dotfiles ~/.dotfiles \
    --deploy portable
```

assuming he has in `flake.nix` a derivation named `portable` for just this
occasion. To run any applications (e.g. `vim`) included in the `portable`
package, Wallace will need to use `nix-portable` (which has been installed at
`~/.nixphile/bin/nix-portable`). Assuming Wallace's dotfiles add
`~/.nixphile/bin` to `$PATH`, he can run `vim` portably by going

```sh
nix-portable vim
```

# executables

## install
```sh
./install --nix (multiuser | portable) [--dotfiles SRC DEST] [--deploy NAME]
```

* Dependencies:
    * At least one of [nix-portable], [curl], or [wget].
    * nix-portable is supposed to have essentially zero dependencies. However,
      see [the README][nix-portable] for some system requirements. Also,
      nix-portable seems to require [bash]isms.

* The `--nix` command is a glorified wrapper around [Nix's install
  script][nix-download] that additionally wraps the `nix` executable in
  `nix-portable` if `portable` mode is chosen.
    * Install `nix-portable`, which is the sole dependency of this project.
        * Try finding it in `$PATH`, then at `$HOME/.nixphile/bin/nix-portable`,
          then `./nix-portable`, then try fetching with `curl` or `wget`.
        * If found somewhere other than `$PATH`, then install to
          `$HOME/.nixphile/bin/nix-portable`.
    * If the `multiuser` mode is chosen, then install Nix in multiuser mode
      (requires sudo).
    * The `$HOME/.nixphile/bin/nix` executable is installed, pointing either to
      system-installed Nix or `nix-portable`-wrapped `nix`.

* The optional `--dotfiles` command installs the git repository `SRC` to
  local path `DEST` using `nix`-wrapped `git`.

* The optional `--deploy` command runs `deploy DEST#NAME` (see below) after
  the other install jobs.

## deploy
```sh
nix run 'github:abstrnoah/nixphile#deploy' [INSTALLABLE]    # as flake app
./deploy [INSTALLABLE]                                      # natively
```

* Dependency: `nix`
    * If you run it as a flake app then obviously you can use whatever Nix you
      want.
    * If you run it natively as a shell script, then it will try to find `nix`
      (first) in `$PATH` or (second) at `$HOME/.nixphile/bin/nix`. The second
      location is where [install](#install) places Nix.

* For the meaning of `INSTALLABLE`, see nix3-build(1) manpage. Essentially,
  it's a flake URL to a Nix derivation.

* If `INSTALLABLE` is omitted, then remove an existing deployment; otherwise...

* Remove any existing deployment.
* Build `INSTALLATION`.
* Link the output to `$HOME/.nixphile/env`.
* Deploy the file tree found at `$HOME/.nixphile/env/home/me` to `$HOME`
  with symlinks in basically the same way as GNU Stow[^1].
* Try to be atomic so that, if something goes wrong, then the
  previously-deployed `$HOME/.nixphile/env` is replaced.

# Nix library

Found in the `lib.nix` file; documentation forthcoming (TODO).

# alternatives

TODO

---

[^1]: At this time, the tool uses [xstow] to perform the symlink
deployment. As mentioned above, stow suffers from under-maintenance and is
[unable to handle absolute symlinks][stow-absolutes] in the source tree, which
is crucial for deploying Nix derivations.
[^2]: I don't intend to document Nix in this README; see the [homepage][nix] for
documentation

[stow-undermaint]: https://github.com/aspiers/stow/issues/33#issuecomment-1431786737
[stow-absolutes]: https://github.com/aspiers/stow/issues/3
[xstow]: https://xstow.sourceforge.net/
[nix-portable]: https://github.com/DavHau/nix-portable
[curl]: https://curl.se/
[unix-philosophy]: https://en.wikipedia.org/wiki/Unix_philosophy
[stow]: https://www.gnu.org/software/stow/
[nix]: https://nixos.org/
[wget]: https://www.gnu.org/software/wget/
[bash]: https://www.gnu.org/software/bash/
[nix-download]: https://nixos.org/download.html
[debian]: https://www.debian.org/
[home-manager]: https://nix-community.github.io/home-manager/
