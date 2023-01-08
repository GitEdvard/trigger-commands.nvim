local M = {}

local to_vim_script_arr = function(lua_table)
    -- lua table contains strings only. Escape each single quote in it
    local escaped_table = {}
    for _, v in ipairs(lua_table) do
        local row = string.gsub(v, "'", "''")
        table.insert(escaped_table, row)
    end
    return '[\'' .. table.concat(escaped_table, '\',\'') .. '\']'
end

local move_cursor = function(prompt_win, nrrows)
    local pos, _ = vim.api.nvim_win_get_cursor(prompt_win)
    local new_line = pos[1] + nrrows
    vim.api.nvim_win_set_cursor(prompt_win, {new_line, 0})
end

local var_placeholders = {
    ['${file}'] = function(_)
        return vim.fn.expand("%:p")
    end,
    ['${fileBasename}'] = function(_)
        return vim.fn.expand("%:t")
    end,
    ['${fileBasenameNoExtension}'] = function(_)
        return vim.fn.fnamemodify(vim.fn.expand("%:t"), ":r")
    end,
    ['${fileDirname}'] = function(_)
        return vim.fn.expand("%:p:h")
    end,
    ['${fileExtname}'] = function(_)
        return vim.fn.expand("%:e")
    end,
    ['${relativeFile}'] = function(_)
        return vim.fn.expand("%:.")
    end,
    ['${relativeFileDirname}'] = function(_)
        return vim.fn.fnamemodify(vim.fn.expand("%:.:h"), ":r")
    end,
    ['${workspaceFolder}'] = function(_)
        return vim.fn.getcwd()
    end,
    ['${workspaceFolderBasename}'] = function(_)
        return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
    end,
    ['${env:([%w_]+)}'] = function(match)
        return os.getenv(match) or ''
    end,
}

local expand_values = function(option)
    for key, fn in pairs(var_placeholders) do
        option = option:gsub(key, fn)
    end
    return option
end

M._generate_command = function(run_settings)
    local command_candidate = {}
    table.insert(command_candidate, run_settings.type)
    table.insert(command_candidate, run_settings.command)
    if run_settings['args'] == nil then
        run_settings.args = {}
    end
    for _, v in ipairs(run_settings.args) do
        table.insert(command_candidate, v)
    end
    local command = vim.tbl_map(expand_values, command_candidate)
    return command
end

M._generate_command_multi = function(run_settings)
    local commands = {}
    for _, setting in ipairs(run_settings) do
        table.insert(commands, M._generate_command(setting))
    end
    return commands
end

local spawn_scratch_window = function()
    local original_win = vim.api.nvim_get_current_win()
    vim.cmd.vnew()
    -- Make it a scratch buffer
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = 0, silent = true, noremap = true })
    vim.cmd{cmd = "setlocal", args = {"buftype=nofile"}}
    vim.cmd{cmd = "setlocal", args = {"bufhidden=hide"}}
    vim.cmd{cmd = "setlocal", args = {"noswapfile"}}
    local bufnr = vim.api.nvim_get_current_buf()
    local prompt_win = vim.api.nvim_get_current_win()
    -- vim.api.nvim_set_current_win(original_win)
    return bufnr, prompt_win
end

local show_and_gather_err = function(data, err_output, bufnr, prompt_win)
    if not data then
        return err_output
    end
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
    move_cursor(prompt_win, #data)
    for _, row in ipairs(data) do
        table.insert(err_output, row)
    end
    return err_output
end

local show = function(data, bufnr, prompt_win)
    if not data then
        return
    end
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
    move_cursor(prompt_win, #data)
end

local show_errors = function(exit_code, err_output, bufnr, prompt_win)
    if exit_code ~= 0 then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"Program returned error. Output written to the quickfix."})
        move_cursor(prompt_win, 1)
        local vim_script_arr = to_vim_script_arr(err_output)
        vim.cmd { cmd = 'cgetexpr', args = {vim_script_arr} }
    end
end

M.run_single = function(run_settings)
    if run_settings == nil or next(run_settings) == nil then
        error('run settings is empty')
    end
    local bufnr, prompt_win = spawn_scratch_window()
    local command = M._generate_command(run_settings)
    local err_output = {}
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Waiting for script output ..."})
    vim.fn.jobstart(command, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            show(data, bufnr, prompt_win)
        end,
        on_stderr = function(_, data)
            err_output = show_and_gather_err(data, err_output, bufnr, prompt_win)
        end,
        on_exit = function(_, exit_code, _)
            show_errors(exit_code, err_output, bufnr, prompt_win)
        end
    })
end

M.run_rest_call = function(run_settings)
    if run_settings == nil or next(run_settings) == nil then
        error('run settings is empty')
    end
    local commands = M._generate_command_multi(run_settings)
    if #commands ~= 2 then
        local found = #commands
        if found == 0 then found = 1 end
        error('For rest calls, 2 run-settings are expected! Found: ' .. found)
    end
    local bufnr, prompt_win = spawn_scratch_window()
    local server_command = commands[1]
    local rest_command = commands[2]
    local err_output = {}
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Waiting for script output ..."})
    vim.fn.jobstart(server_command, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            show(data, bufnr, prompt_win)
        end,
        on_stderr = function(_, data)
            err_output = show_and_gather_err(data, err_output, bufnr, prompt_win)
        end,
        on_exit = function(_, exit_code, _)
            P(err_output)
            show_errors(exit_code, err_output, bufnr, prompt_win)
        end
    })
    vim.fn.jobstart(rest_command, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            show(data, bufnr, prompt_win)
        end,
        on_stderr = function(_, data)
            show(data, bufnr, prompt_win)
        end,
    })
end

return M
