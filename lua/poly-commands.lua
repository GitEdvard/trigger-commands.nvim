require'globals'

local M = {}

local run_silent = require'silent-commands'.run_silent

local gather_output = require'silent-commands'.gather_output

local show_errors_silent = require'silent-commands'.show_errors

local show = require'common'.show

local show_errors = require'common'.show_errors

local show_and_gather_err = require'common'.show_and_gather_err

local spawn_console_window_silent = require'common'.spawn_console_window_silent

local mysplit = require'common'.mysplit

run_silent_rec = function(instructions, i)
  local input = instructions[i]
  setmetatable(input, {__index={cmd_description = "Build"}})
  local command, cmd_description =
    input[2],
    input[3] or input.cmd_description
  print("Starting " .. cmd_description .. "...")
  local build_output = {}
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      build_output = gather_output(data, build_output)
    end,
    on_stderr = function(_, data)
      build_output = gather_output(data, build_output)
    end,
    on_exit = function(_, exit_code, _)
      if exit_code ~= 0 then
        print(cmd_description .. " failed" .. ", errors written to quickfix")
        show_errors_silent(build_output)
      elseif i < #instructions then
        coordinate_job_rec(instructions, i + 1)
      else
        print(cmd_description .. " succeeded!")
      end
    end
  })
end

coordinate_job_rec = function(instructions, i)
  local job_type = instructions[i][1]
  if job_type == "silent" then
    run_silent_rec(instructions, i)
  elseif job_type == "hidden-scratch" then
    jobstart_hidden_scratch_rec(instructions, i)
  else
    print("Unrecognized option for job_type: "  .. job_type)
    print("Should be one of 'silent', 'hidden-scratch'")
  end
end

local has_any_keyword = function(bufnr, keywords)
  local contents = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  for k, v in pairs(contents) do
    for _, single_keyword in pairs(keywords) do
      if v:find(single_keyword) then
        return true
      end
    end
  end
  return false
end

local transform_errors = function(err_output)
  local new_output = {}
  for _, row in pairs(err_output) do
    _, _, path, line = row:find("%s*at%s*(.*)%(.*:(%d+)%)")
    if path ~= nil then
      local split_path = mysplit(path, "%p")
      table.remove(split_path)
      local family = split_path[1]
      local project = split_path[2]
      local modified_path = family .. "." .. project  .. "\\src\\" .. table.concat(split_path, "\\") .. ".java"
      local update_row = " att " .. modified_path .. "(" .. line .. ")"
      table.insert(new_output, update_row)
    else
      table.insert(new_output, row)
    end
  end
  return new_output
end

jobstart_hidden_scratch_rec = function(instructions, i)
  local input = instructions[i]
  setmetatable(input, {__index={cmd_description = "Build" }})
  local command, error_keywords, cmd_description, bufnr, promt_win =
    input[2],
    input[3],
    input[4] or input.cmd_description,
    input[5],
    input[6]
  print("Starting " .. cmd_description .. "...")
  local err_output = {}
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      show(data, bufnr, prompt_win)
    end,
    on_stderr = function(_, data)
      err_output = show_and_gather_err(data, err_output, bufnr, prompt_win)
    end,
    on_exit = function(_, exit_code, _)
      local show_err = has_any_keyword(bufnr, error_keywords)
      if show_err then
        print(cmd_description .. " failed" .. ", errors written to quickfix")
        local new_output = transform_errors(err_output)
        show_errors(new_output, bufnr, prompt_win)
      elseif i < #instructions then
        coordinate_job_rec(instructions, i + 1)
      else
        show({"Done."}, bufnr, prompt_win)
        print(cmd_description .. " succeeded!")
      end
    end
  })
end

M.run_poly = function(instructions)
  local bufnr, prompt_win = spawn_console_window_silent()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Waiting for script output ..."})
  for _, v in pairs(instructions) do
    local job_type = v[1]
    if job_type == "hidden-scratch" then
      table.insert(v, bufnr)
      table.insert(v, prompt_win)
    end
  end
  coordinate_job_rec(instructions, 1)
end

return M
