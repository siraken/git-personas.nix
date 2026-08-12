# git-personas.nix

A home-manager module for people who work across several git forges — a
personal account, an employer, a client — and want each one's identity and
credentials confined to its own directory.

A **persona** is a directory plus the identity, credentials, and environment
that apply inside it. Which persona you are wearing follows from where you are.

The persona list lives in a TOML file **outside** the flake and is read at
*activation* time, never during evaluation. The flake stays pure (no
`--impure`), the hostnames never enter the repository, and a machine without
the file simply gets no persona configuration.

## What it does

For every persona the module can:

- **include a hand-maintained gitconfig** for repositories under its directory,
  via `includeIf "gitdir:…"` — the usual per-directory identity trick;
- **confine a stored credential to that directory**, by emptying the credential
  helper list for the persona's hosts globally and putting it back only inside
  the include. Outside the directory git cannot reach the stored token at all;
- **export environment variables** for the directory, by writing a direnv
  `.envrc` at its root — useful for tools that key off a host, such as
  `GITLAB_HOST` for [glab](https://gitlab.com/gitlab-org/cli).

## Usage

```nix
{
  inputs.git-personas = {
    url = "github:siraken/git-personas.nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };
}
```

```nix
{ config, inputs, ... }:
{
  imports = [ inputs.git-personas.homeModules.default ];

  programs.gitPersonas = {
    enable = true;
    personasFile = "${config.home.homeDirectory}/dotfiles/personas.toml";
    # reposRoot = "${config.home.homeDirectory}/repos";              # default
    # configDir = "${config.home.homeDirectory}/.config/git.custom";  # default
  };
}
```

### The personas file

TOML.

```toml
[[gitPersonas]]
dir = "github.com/example-org"
configFile = "example-org"
credentialHosts = ["https://git.example.com"]
env.GITLAB_HOST = "git.example.com"
```

| field | required | meaning |
| --- | --- | --- |
| `dir` | yes | Directory holding the persona's repositories, relative to `reposRoot`. |
| `configFile` | yes | Gitconfig for those repositories, relative to `configDir`. You write this file yourself. |
| `credentialHosts` | no | Hosts whose stored credential must only be reachable from `dir`. |
| `env` | no | Variables exported by a generated `.envrc` at the root of `dir`. |

Keep the file out of version control if the hostnames are sensitive; it is
never read at evaluation time, so nothing here reaches the store.

The per-persona gitconfig is yours to maintain. To make a confined credential
usable, put the helper back in it:

```gitconfig
[user]
	name = Your Name
	email = you@example.com

[credential "https://git.example.com"]
	helper = osxkeychain
```

## Options

| option | default | |
| --- | --- | --- |
| `programs.gitPersonas.enable` | `false` | |
| `programs.gitPersonas.personasFile` | — | Absolute path to the TOML file. |
| `programs.gitPersonas.reposRoot` | `~/repos` | What `dir` is resolved against, typically a ghq root. |
| `programs.gitPersonas.configDir` | `~/.config/git.custom` | Where the per-persona gitconfigs and the generated include live. |
| `programs.gitPersonas.includeFile` | `<configDir>/personas.gitconfig` | The generated include. |
| `programs.gitPersonas.writeEnvrc` | `true` | Whether to write `.envrc` files. |

## Things to know

- **Cloning outside the directory stops working for confined hosts** — that is
  the point of `credentialHosts`, but it means `git clone` run from elsewhere
  will ask for a password. Cloning *into* the directory works: git re-reads its
  configuration once the repository exists, so `ghq get` is unaffected as long
  as its root is `reposRoot`.
- **direnv loads the nearest `.envrc` only.** A repository with its own
  `.envrc` will not see the generated one; call `source_up` there if you need
  the variables.
- A generated `.envrc` needs `direnv allow` once, and again whenever its
  contents change.
- An `.envrc` this module did not write is never overwritten — it is left alone
  with a warning on stderr.
- A malformed personas file aborts the activation step without touching the
  configuration already in place.

## License

[MIT](LICENSE)
