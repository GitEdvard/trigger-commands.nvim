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

M.run = function()
    local original_win = vim.api.nvim_get_current_win()
    vim.cmd.vnew()
    local bufnr = vim.api.nvim_get_current_buf()
    local prompt_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(original_win)
    program = "/home/edvard/sources/snpseq/clarity-snpseq/clarity-ext/clarity_ext/cli.py"
    args = { "--level", "INFO", "extension", "--cache", "False", "clarity_ext_scripts.dilution.dna_dilution_start", "test" }
    local command = args
    table.insert(command, 1, program)
    table.insert(command, 1, "python")
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
