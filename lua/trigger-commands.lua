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
    for _, v in ipairs(run_settings.args) do
        table.insert(command_candidate, v)
    end
    local command = vim.tbl_map(expand_values, command_candidate)
    return command
end

M.run = function(run_settings)
    local original_win = vim.api.nvim_get_current_win()
    vim.cmd.vnew()
    -- Make it a scratch buffer
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = 0, silent = true, noremap = true })
    vim.cmd{cmd = "setlocal", args = {"buftype=nofile"}}
    vim.cmd{cmd = "setlocal", args = {"bufhidden=hide"}}
    vim.cmd{cmd = "setlocal", args = {"noswapfile"}}
    local bufnr = vim.api.nvim_get_current_buf()
    local prompt_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(original_win)
    local command = M._generate_command(run_settings)
    local err_output = {}
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Waiting for script output ..."})
    vim.fn.jobstart(command, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if not data then
                return
            end
            vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
            move_cursor(prompt_win, #data)
        end,
        on_stderr = function(_, data)
            if not data then
                return
            end
            -- local data_vim_arr = to_vim_script_arr(data)
            vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
            for _, row in ipairs(data) do
                table.insert(err_output, row)
            end
            move_cursor(prompt_win, #data)
        end,
        on_exit = function(_, exit_code, _)
            if exit_code ~= 0 then
                vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"Program returned error. Output written to the quickfix."})
                move_cursor(prompt_win, 1)
                local vim_script_arr = to_vim_script_arr(err_output)
                vim.cmd { cmd = 'cgetexpr', args = {vim_script_arr} }
            end

        end
    })
end

return M
