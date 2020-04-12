# Potato

[![Hex](https://img.shields.io/hexpm/v/potato.svg)](https://hex.pm/packages/potato) [![Build Status](https://travis-ci.org/ausimian/potato.svg?branch=master)](https://travis-ci.org/ausimian/potato)

Mix tasks to assist in the generation of upgradeable releases.

- `potato.full` - Generates a full upgradeable release.
- `potato.upgrade` - Generates a minimal upgrade release.

Both of these tasks leverage the work done by the existing 
[mix release](https://hexdocs.pm/mix/Mix.Release.html#content) task, and this
task must be run prior to running potato.

Full releases can be untarred as normal, but an additional `preboot.sh` script
is placed in the versioned release directory, and should be run prior to first
system boot if you require that your system support downgrading to this initial
release.

Upgrades should be installed via [release_handler](http://erlang.org/doc/man/release_handler.html).

It's not magic. You are still responsible for writing the relevant appup files. I
do this via overlays.

Also, see the disclaimer below.

## Usage

```shell
$ git clone http://example.com/myrepo.git
...
$ cd myrepo
$ git checkout v1.0.0
$ MIX_ENV=prod mix do release, potato.full
...
Generated full release in /home/user/myrepo/_build/prod/rel/myrepo-1.0.0.tar.gz.
$ git checkout v1.0.1
$ MIX_ENV=prod mix do release, potato.full, potato.upgrade --from 1.0.0
...
Generated full release in /home/user/myrepo/_build/prod/rel/myrepo-1.0.1.tar.gz.
Generated upgrade release in /home/user/myrepo/_build/prod/rel/myrepo/releases/myrepo-1.0.1.tar.gz.
```

## Installation

The package can be installed by adding `potato` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:potato, "~> 0.1.0", :only: :dev, runtime: false}
  ]
end
```

The docs can be found at [https://hexdocs.pm/potato](https://hexdocs.pm/potato).

## Disclaimer

Hacked together and barely tested. Seek alternatives at the first sign of trouble.
