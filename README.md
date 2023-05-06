# trigger-commands

Trigger any command within vim, so that stdout and stderr is shown in a scratch window. Stderr is also directed to the quickfix window. 

## Motivation

1) Show errors in quickfix window
2) Reduce swapping between vim and terminal when doing a code-run-validate loop. Specificly when developing a rest service, which has this extra start and stop a service before trigger a rest call.

## Requirements

https://github.com/GitEdvard/read-settings.nvim

You have to setup the ```errorformat``` variable for your programming language. 

## Setup
Create a .runsettings.json file at the root of your repository. A run setting must have the fields "type" and "command". The field "args" is optional.

Example single command setup:

```
{
  "type": "python",
  "program": "${workspaceFolder}/hello.py",
  "args": {"world!"}
}
```
Corresponding init.vim
```
local run_settings = require'read-settings'.read_json('.runsettings.json')
local trigger_command = function()
    local cmd = require'trigger_commands'.generate_command(run_settings)
    require'trigger-commands'.run_single(cmd)
end
local opts = { noremap = true, silent = true }
vim.keymap.set('n', '<leader>ur', trigger_command, opts)
```
Note the difference from rest call commands, regarding run_settings instead of cmd.

Example rest service command setup:

```
[
  {
    "type": "python",
    "program": "${workspaceFolder}/myserver.py",
    "args": { "--port", "2000" }
  },
  {
    "type": "curl",
    "program": "localhost:2000/api/hello"
  }
]
```

Corresponding init.lua setup (note the "run_rest_call" command):

```
local run_settings = require'read-settings'.read_json('.runsettings.json')
local trigger_command = function()
    require'trigger-commands'.run_rest_call(run_settings)
end
local opts = { noremap = true, silent = true }
vim.keymap.set('n', '<leader>ur', trigger_command, opts)
```

## Run setup keywords

- Some variables are supported:
- `${file}`: Active filename
- `${fileBasename}`: The current file's basename
- `${fileBasenameNoExtension}`: The current file's basename without extension
- `${fileDirname}`: The current file's dirname
- `${fileExtname}`: The current file's extension
- `${relativeFile}`: The current file relative to |getcwd()|
- `${relativeFileDirname}`: The current file's dirname relative to |getcwd()|
- `${workspaceFolder}`: The current working directory of Neovim
- `${workspaceFolderBasename}`: The name of the folder opened in Neovim
- `${env:Name}`: Environment variable named `Name`, for example: `${env:HOME}`.

These variable names are taken from nvim-dap: https://github.com/mfussenegger/nvim-dap/blob/master/doc/dap.txt

For a single command setting, one can use the same setting as nvim-dap. However, trigger-commands will only look for the arguments "type", "program" and "args".

Example using an enviroment variable in run settings:

```
{
  "type": "python",
  "program": "${workspaceFolder}/hello.py",
  "args": {"${env:HELLO}"}
}
```
in init.lua:

```
local run_settings = require'read-settings'.read_json('.runsettings.json')
local trigger_command = function()
    vim.cmd("let $HELLO = 'world!'")
    require'trigger-commands'.run_single(run_settings)
end
local opts = { noremap = true, silent = true }
vim.keymap.set('n', '<leader>ur', trigger_command, opts)
```

