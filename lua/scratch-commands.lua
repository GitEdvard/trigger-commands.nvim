local M = {}

local spawn_scratch_window = require'common'.spawn_scratch_window

local spawn_console_window = require'common'.spawn_console_window

local spawn_console_window_silent = require'common'.spawn_console_window_silent

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

local has_keyword = function(bufnr, keyword)
  local contents = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  for k, v in pairs(contents) do
    if v:find(keyword) then
      return true
    end
  end
  return false
end

-- M.run_launcher = function(command, error_keyword)
M.run_launcher = function(input)
  setmetatable(input, {__index={succeed_string = "Build succeeded!", failed_string = "Build failed. "}})
  local command, error_keyword, succeed_string, failed_string =
    input[1] or input.command,
    input[2] or input.error_keyword,
    input[3] or input.succeed_string,
    input[4] or input.failed_string
  local bufnr, prompt_win = spawn_console_window_silent()
  local err_output = {}
  local error_found = false
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Waiting for script output ..."})
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      show(data, bufnr, prompt_win)
    end,
    on_stderr = function(_, data)
      err_output = show_and_gather_err(data, err_output, bufnr, prompt_win)
    end,
    on_exit = function(_, _, _)
      local show_err = has_keyword(bufnr, error_keyword)
      if show_err then
        print(failed_string)
        show_errors(err_output, bufnr, prompt_win)
      else
        print(succeed_string)
      end
    end
  })
end

return M

