local M = {}
M.run = function()
    local original_win = vim.api.nvim_get_current_win()
    vim.cmd.vnew()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_win(original_win)
    program = "/home/edvard/sources/snpseq/clarity-snpseq/clarity-ext/clarity_ext/cli.py"
    args = { "--level", "INFO", "extension", "--cache", "False", "clarity_ext_scripts.dilution.dna_dilution_start", "test" }
    local command = args
    table.insert(command, 1, program)
    table.insert(command, 1, "python")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Waiting for script output ..."})
    vim.fn.jobstart(command, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if not data then
                return
            end
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)
        end,
    })
end

return M
