# centcmds

CompiOS for CC:Tweaked.

## Project structure

```text
.
|-- apps/
|   |-- snake.lua
|   `-- terminal.lua
|-- core/
|   |-- boot.lua
|   `-- loading.lua
|-- gui/
|   |-- desktop.lua
|   `-- ui.lua
|-- centcmds.lua
|-- delete-centcmds.lua
|-- download.lua
|-- main.lua
|-- reinstall-centcmds.lua
`-- update-centcmds.lua
```

## Quick install in CC:Tweaked

```lua
wget run https://raw.githubusercontent.com/devBELUGA/centcmds/main/download.lua
```

After install:

```lua
centcmds
```

Service commands:

```lua
reinstall-centcmds
update-centcmds
delete-centcmds
```
