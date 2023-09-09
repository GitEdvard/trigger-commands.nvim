local M = {}

local spawn_scratch_window = require'common'.spawn_scratch_window

local show_and_gather_err = require'common'.show_and_gather_err

local show = require'common'.show

local show_errors = require'common'.show_errors

jobstart_rec = function(commands, i, err_output, bufnr, prompt_win)
  vim.fn.jobstart(commands[i], {
    stdout_buffered = true,
    on_stdout = function(_, data)
      show(data, bufnr, prompt_win)
    end,
    on_stderr = function(_, data)
      local err_output = show_and_gather_err(data, err_output, bufnr, prompt_win)
    end,
    on_exit = function(_, exit_code, _)
      if i < #commands then
        jobstart_rec(commands, i + 1, err_output, bufnr, prompt_win)
      else
        show({"Done."}, bufnr, prompt_win)
      end
      if exit_code ~= 0 then
      end
    end
  })
end

M.run_multi = function(commands)
  local bufnr, prompt_win = spawn_scratch_window()
  local err_output = {}
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Waiting for script output ..."})
  jobstart_rec(commands, 1, err_output, bufnr, prompt_win)
end

M.run_single = function(command)
  local bufnr, prompt_win = spawn_scratch_window()
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
      if exit_code ~= 0 then
        show_errors(err_output, bufnr, prompt_win)
      end
    end
  })
end

return M

