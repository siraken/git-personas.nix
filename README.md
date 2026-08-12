# git-clients.nix

A home-manager module for people who work across several git forges — a
personal account, an employer, a client — and want each one's identity and
credentials confined to its own directory.

The client list lives in a JSON file **outside** the flake and is read at
*activation* time, never during evaluation. The flake stays pure (no
`--impure`), the client's hostnames never enter the repository, and a machine
without the file simply gets no client configuration.

## What it does

For every client entry the module can:

- **include a hand-maintained gitconfig** for repositories under the client's
  directory, via `includeIf "gitdir:…"` — the usual per-directory identity trick;
- **confine a stored credential to that directory**, by emptying the credential
  helper list for the client's hosts globally and putting it back only inside
  the include. Outside the directory git cannot reach the stored token at all;
- **export environment variables** for the directory, by writing a direnv
  `.envrc` at its root — useful for tools that key off a host, such as
  `GITLAB_HOST` for [glab](https://gitlab.com/gitlab-org/cli).

## Usage

```nix
{
  inputs.git-clients = {
    url = "github:siraken/git-clients.nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };
}
```

```nix
{ config, inputs, ... }:
{
  imports = [ inputs.git-clients.homeModules.default ];

  programs.gitClients = {
    enable = true;
    clientsFile = "${config.home.homeDirectory}/dotfiles/secrets.json";
    # reposRoot = "${config.home.homeDirectory}/repos";            # default
    # configDir = "${config.home.homeDirectory}/.config/git.custom"; # default
  };
}
```

### The clients file

```json
{
  "gitClients": [
    {
      "dir": "github.com/example-org",
      "configFile": "example-org",
      "credentialHosts": ["https://git.example.com"],
      "env": { "GITLAB_HOST": "git.example.com" }
    }
  ]
}
```

| field | required | meaning |
| --- | --- | --- |
| `dir` | yes | Directory holding the client's repositories, relative to `reposRoot`. |
| `configFile` | yes | Gitconfig for those repositories, relative to `configDir`. You write this file yourself. |
| `credentialHosts` | no | Hosts whose stored credential must only be reachable from `dir`. |
| `env` | no | Variables exported by a generated `.envrc` at the root of `dir`. |

Keep the file out of version control if the client names are sensitive; it is
never read at evaluation time, so nothing here reaches the store.

The per-client gitconfig is yours to maintain. To make a confined credential
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
| `programs.gitClients.enable` | `false` | |
| `programs.gitClients.clientsFile` | — | Absolute path to the JSON file. |
| `programs.gitClients.reposRoot` | `~/repos` | What `dir` is resolved against, typically a ghq root. |
| `programs.gitClients.configDir` | `~/.config/git.custom` | Where the per-client gitconfigs and the generated include live. |
| `programs.gitClients.includeFile` | `<configDir>/clients.gitconfig` | The generated include. |
| `programs.gitClients.writeEnvrc` | `true` | Whether to write `.envrc` files. |

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

## License

MIT
