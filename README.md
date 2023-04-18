# nixphile

A simple Nix-centric dotfiles deployer.

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
  them. (TODO; fork from 'abstrnoah/dotfiles/lib.nix'.)

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

# dependencies

The only real dependency is [nix-portable]; if you can run it then you can run
`nixphile`. The nix-portable executable is supposed to have essentially zero
dependencies. But see [the README][nix-portable] for some system requirements.
Also, nix-portable seems to require [bash]isms.

In order for the script to automatically install Nix or nix-portable, it needs
one of [nix-portable], [curl], or [wget].

# synopsis

```sh
[NIXPHILE_MODE=(multiuser | portable | auto)] ./nixphile [<flake-url>]
```

# details

The nixphile script first tries to locate a working copy of Nix and second
deploys `<flake-url>` to `$HOME` as outlined in the following subsections.

The argument `<flake-url>` is passed directly to nix3-build(1); see the manpage
for details. Usually a flake url takes the form `url#name` where `url` is the
location of a repository and `name` is the package to be deployed. Often `url`
will be a GitHub reference like `github:username/dotfiles` and `package` will be
the dotfiles profile you wish to deploy, like `thinkpad-laptop`. Perhaps the
most common `url` will be the current directory, just `.`; in that case the full
flake url would be something like `.#thinkpad-laptop`.

## obtaining nix

* Try finding an existing copy of Nix:
    * `NIXPHILE_MODE` is `multiuser`: Look for `nix` executable in `$PATH` or at
      `~/.nixphile/bin/nix` (in that order).
    * `NIXPHILE_MODE` is `portable`: Look for `nix-portable` executable in
      `$PATH`, at `./nix-portable`, or at `~/.nixphile/bin/nix-portable` (in
      that order).
    * `NIXPHILE_MODE` is `auto` (the default): Look for `nix`, then
      `nix-portable`.
* Otherwise try installing Nix:
    * `multiuser`: Try installing Nix in multi-user (`--daemon`) mode.
    * `portable` or `auto`: Try fetching nix-portable and installing it to
      `~/.nixphile/bin/nix-portable`.

That is, we try to flexibly find an existing copy of Nix, but will only
_install_ Nix in multi-user mode if you explicitly declare
`NIXPHILE_MODE=multiuser`.

The install step involves fetching from the internet, which requires at least
one of `nix-portable`, `curl`, or `wget` to be installed (regardless of
`NIXPHILE_MODE`).

## deploying

Invariant: The currently deployed environment is linked at `~/.nixphile/env`. If
this link exists, then nixphile assumes that `~/.nixphile/env/home/me` is
deployed to `$HOME`.

If no `<flake-url>` is provided, then just remove the currently deployed
environment (if there is one) and exit.

Deploying involves the following procedure:

* Remove any existing deployment.
* Build `<flake-url>`.
* Link the build's output to `$HOME/.nixphile/env`.
* Deploy the file tree found at `$HOME/.nixphile/env/home/me` to `$HOME` in
  basically the same way as GNU Stow[^1].

We try to be atomic insofar as, if something goes wrong, then we attempt to
replace `$HOME/.nixphile/env` with the previous deployment (if there was one)
and re-stow it to `$HOME`.

# example

To be more concrete, suppose Wallace (username `wallace`) has a nice dotfiles
repository at `https://github.com/wallace/dotfiles`. He creates a file named
`flake.nix` in the root of this repository and writes a Nix expression that
provides his dotfiles as one or more "packages"[^2].

Wallace now wants to setup a completely new machine named `gromit` that just has
`curl` installed. Wallace probably wants to run something like

```sh
NIXPHILE_MODE=multiuser \
sh <(curl -L https://raw.githubusercontent.com/abstrnoah/nixphile/main/nixphile) \
    'github:wallace/dotfiles#gromit'
```

This assumes that Wallace has created a Nix derivation named `gromit` in the
`flake.nix` file, with the implication that `gromit` holds the environment
intended for the new machine. Namely, any files located at `/home/me` in the
output of `gromit` will be deployed to Wallace's new `$HOME` directory via
symlink. Since Wallace declares `multiuser` mode, Nix will be installed as root
assuming Wallace has sufficient privileges.

On the other hand, if Wallace is given access to a machine where he doesn't have
root privileges but still wants the comfort of his dotfiles, then he could run

```sh
sh <(curl -L https://raw.githubusercontent.com/abstrnoah/nixphile/main/install) \
    'github:wallace/dotfiles#portable'
```

assuming he has in `flake.nix` a derivation named `portable` for just this
occasion. Finding no existing version of Nix, the script will fallback to
obtaining `nix-portable` and proceeding in portable mode. To run any
applications (e.g. `vim`) included in the `portable` package, Wallace will need
to use `nix-portable` (which has been installed at
`~/.nixphile/bin/nix-portable`). Assuming Wallace's dotfiles add
`~/.nixphile/bin` to `$PATH`, he can run `vim` portably by going

```sh
nix-portable vim
```

TODO: Minimal `flake.nix` example (namely, for people who don't want to use Nix
for anything).

# alternatives

As acknowledged above, there are more dotfiles managers out there than is good
for the human race. I admit that I have only investigated the following tools in
earnest; at some point I started just skimming new projects and pretty
quickly discarding them as either ineffective or overkill (sorry).

* [chezmoi]
* [home-manager]
* [stow]

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
[chezmoi]: https://www.chezmoi.io/
