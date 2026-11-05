# kerf

a small, fast terminal coding agent written in guile scheme. no build step.
requires `guile` 3.0 and `curl`.

kerf talks to any openai-compatible `/chat/completions` endpoint, runs a tight
tool loop, and keeps the terminal as the interface. it is meant to feel sharp
and quiet: a start page, a compact chat view, and direct keybinds instead of
menus.

## run

    ./kerf

first run writes `~/.config/kerf/config.json`.

set a key:

    export KERF_API_KEY=...

`OPENAI_API_KEY` works too. point `base_url` at a local server to use a local
model.

## start page

kerf opens on a tabbed start page before a session starts.

- `Session`: session details, server, model, workdir, and quick actions
- `Servers`: saved profiles, connection details, and server management
- `Options`: settings editor
- `About`: version, paths, keybinds, and tool list

tabs: `tab` / `shift-tab`. select: `enter`. back: `esc`. quit: `q`.

global keybinds:

- `ctrl-s` options
- `ctrl-o` servers
- `ctrl-n` quick connect
- `ctrl-c` quit
- `page up` / `page down` scroll

## chat

- `enter` send
- `up` / `down` history
- `ctrl-u` clear input
- `page up` / `page down` scroll
- `/help` commands

slash commands:

- `/clear`, `/help`, `/tools`, `/config`
- `/model NAME`
- `/cd PATH`
- `/server`, `/options`
- `/connect HOST:PORT`

## tools

`bash`, `read`, `write`, `edit`, `list`, `grep`, `glob`, `patch`,
`webfetch`, `todowrite`, `todoread`.

legacy names such as `read_file`, `write_file`, `edit_file`, and `list_dir`
still work.

writes, edits, patches, and shell commands ask for confirmation unless
`auto_approve` is set in the config.

## connect

kerf can use an api key from three places:

- `KERF_API_KEY` or `OPENAI_API_KEY` in the environment
- the `api_key` field in `~/.config/kerf/config.json`, editable from `Options`
- the `key` field of a saved server profile

connect to a server:

- `ctrl-n` and enter `host:port` or a full url
- `Servers` tab, then `enter` on a saved profile
- `/connect HOST:PORT` in chat

quick connect and import fetch `/models` when available. local servers on
`127.0.0.1` or `localhost` do not require an api key.

## servers

saved profiles live in the config file. each profile stores host, port, scheme,
path, model, and an api key environment variable.

- add/edit/delete/test profiles in the `Servers` tab
- quick connect with `ctrl-n` using `host:port` or a full url
- import profiles from a json file with `i`
- connect a saved profile with `enter`

quick connect and import fetch `/models` when available and store the first
returned model.

## local models

kerf sends native openai tool calls and also understands text fallback calls
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

    ./kerf --once "prompt" --yes
    ./kerf --model gpt-4.1-mini
    ./kerf --workdir ~/Projects/thing
    ./kerf --base-url http://127.0.0.1:8080/v1
    ./kerf --server NAME
    ./kerf --connect 192.168.1.42:8080
    ./kerf --list-servers
    ./kerf --tool-mode text
    ./kerf --config
    ./kerf --version

## config

default location: `~/.config/kerf/config.json`.

example:

    {
      "base_url": "https://api.openai.com/v1",
      "model": "gpt-4.1-mini",
      "api_key_env": "KERF_API_KEY",
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
