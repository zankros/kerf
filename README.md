# kerf

[![release](https://img.shields.io/github/v/release/zankros/kerf?label=release)](https://github.com/zankros/kerf/releases)
[![license](https://img.shields.io/badge/license-GPL--3.0-111111)](LICENSE)
[![language](https://img.shields.io/badge/language-guile%20scheme-111111)](https://www.gnu.org/software/guile/)
[![platform](https://img.shields.io/badge/platform-linux-111111)](#requirements)

> a fast, sharp little terminal coding agent.  
> guile scheme. no build step. no telemetry. no noise.

```text
▰ kerf 0.2                                                      start · direct
╭──────────────────────╮   options
│ ▸ Session            │   enter changes a value · s saves · r reloads
│   Servers            │
│   Options            │   ▸ Model           gpt-4.1-mini
│   About              │     Base URL        https://api.openai.com/v1
╰──────────────────────╯
```

kerf talks to any OpenAI-compatible `/chat/completions` endpoint, runs a tight
tool loop, and keeps the terminal as the interface. it is built for speed,
clarity, and local models: a tabbed start page, a compact chat view, saved
server profiles, and direct keybinds instead of nested menus.

## install

one line:

```sh
curl -fsSL https://raw.githubusercontent.com/zankros/kerf/master/install.sh | sh
```

manual:

```sh
git clone https://github.com/zankros/kerf
cd kerf
make install
```

custom prefix:

```sh
make install PREFIX="$HOME/.local"
# or
KERF_PREFIX="$HOME/.local" curl -fsSL https://raw.githubusercontent.com/zankros/kerf/master/install.sh | sh
```

uninstall:

```sh
make uninstall
```

### requirements

- `guile` 3.0+
- `curl`
- a terminal with UTF-8 support

## quick start

```sh
export KERF_API_KEY=...
kerf
```

first run writes `~/.config/kerf/config.json`.

point `base_url` at a local server to use a local model:

```sh
kerf --base-url http://127.0.0.1:8080/v1 --model qwen
```

## start page

kerf opens on a tabbed start page before a session starts.

| tab | purpose |
| --- | --- |
| `Session` | session details, server, model, workdir, quick actions |
| `Servers` | saved profiles, connection details, management |
| `Options` | settings editor |
| `About` | version, paths, keybinds, tools |

navigation:

- `tab` / `shift-tab`: switch tabs
- `enter`: select
- `esc`: back
- `q`: quit
- `ctrl-s`: options
- `ctrl-o`: servers
- `ctrl-n`: quick connect
- `ctrl-c`: quit
- `page up` / `page down`: scroll

## chat

- `enter`: send
- `up` / `down`: history
- `ctrl-u`: clear input
- `page up` / `page down`: scroll

slash commands:

```text
/clear   /help   /tools   /config
/model NAME
/cd PATH
/server   /options
/connect HOST:PORT
```

## tools

```text
bash read write edit list grep glob patch webfetch todowrite todoread
```

legacy names such as `read_file`, `write_file`, `edit_file`, and `list_dir`
still work.

writes, edits, patches, and shell commands ask for confirmation unless
`auto_approve` is set in the config.

## connect

kerf can use an api key from three places:

1. `KERF_API_KEY` or `OPENAI_API_KEY` in the environment
2. the `api_key` field in `~/.config/kerf/config.json`, editable from `Options`
3. the `key` field of a saved server profile

connect to a server:

- `ctrl-n`, then enter `host:port` or a full url
- `Servers` tab, then `enter` on a saved profile
- `/connect HOST:PORT` in chat

quick connect and import fetch `/models` when available. local servers on
`127.0.0.1` or `localhost` do not require an api key.

## servers

saved profiles live in the config file. each profile stores host, port, scheme,
path, model, key environment variable, and an optional api key.

- add, edit, delete, test profiles in the `Servers` tab
- quick connect with `ctrl-n`
- import profiles from a json file with `i`
- connect a saved profile with `enter`

example import file:

```json
{
  "servers": [
    {
      "name": "local",
      "host": "127.0.0.1",
      "port": 8080,
      "scheme": "http",
      "path": "/v1",
      "model": "qwen"
    }
  ]
}
```

## local models

kerf sends native OpenAI tool calls and also understands text fallback calls
from models such as qwen. supported text forms include:

- `<tool_call>{"name":"bash","arguments":{"command":"..."}}</tool_call>`
- `<|tool_call|>...`
- fenced json blocks
- bare json tool objects

if a server rejects tools, kerf retries the request without tools.

## settings

the `Options` tab edits the config directly:

- model, base url, api key, workdir
- tool mode: `auto`, `native`, `text`
- theme: `kerf`, `mono`, `amber`
- temperature, max steps, timeout
- auto approve

`s` saves, `r` reloads, `esc` goes back.

## flags

```text
kerf --once "prompt" --yes
kerf --model gpt-4.1-mini
kerf --workdir ~/Projects/thing
kerf --base-url http://127.0.0.1:8080/v1
kerf --server NAME
kerf --connect 192.168.1.42:8080
kerf --list-servers
kerf --tool-mode text
kerf --config
kerf --version
```

## config

default location: `~/.config/kerf/config.json`.

```json
{
  "base_url": "https://api.openai.com/v1",
  "model": "gpt-4.1-mini",
  "api_key_env": "KERF_API_KEY",
  "api_key": "",
  "workdir": "/home/you/project",
  "auto_approve": false,
  "max_steps": 16,
  "timeout": 300,
  "temperature": 0.2,
  "tool_mode": "auto",
  "theme": "kerf",
  "servers": [],
  "active_server": ""
}
```

## development

kerf is plain Guile Scheme. there is no build step.

```sh
GUILE_LOAD_PATH=lib guile -c '(use-modules (kerf main))'
./kerf
make install PREFIX=/tmp/kerf-dev
```

project layout:

```text
kerf              launcher
lib/kerf/         scheme modules
install.sh        curl installer
Makefile          install/uninstall
```

## license

GPL-3.0. see [LICENSE](LICENSE).
