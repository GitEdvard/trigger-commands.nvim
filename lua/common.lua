local M = {}

local move_cursor = function(prompt_win, nrrows)
    local pos, _ = vim.api.nvim_win_get_cursor(prompt_win)
    local new_line = pos[1] + nrrows
    vim.api.nvim_win_set_cursor(prompt_win, {new_line, 0})
end

M.spawn_scratch_window = function()
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

M.show_and_gather_err = function(data, err_output, bufnr, prompt_win)
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

M.show = function(data, bufnr, prompt_win)
    if not data then
        return
    end
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
    move_cursor(prompt_win, #data)
end

local to_vim_script_arr = function(lua_table)
    -- lua table contains strings only. Escape each single quote in it
    local escaped_table = {}
    for _, v in ipairs(lua_table) do
        local row = string.gsub(v, "'", "''")
        table.insert(escaped_table, row)
    end
    return '[\'' .. table.concat(escaped_table, '\',\'') .. '\']'
end

M.show_errors = function(err_output, bufnr, prompt_win)
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"Program returned error. Output written to the quickfix."})
    move_cursor(prompt_win, 1)
    local vim_script_arr = to_vim_script_arr(err_output)
    vim.cmd { cmd = 'cgetexpr', args = {vim_script_arr} }
end


return M
