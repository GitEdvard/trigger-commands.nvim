require'globals'

local M = {}

local run_silent = require'silent-commands'.run_silent

local gather_output = require'silent-commands'.gather_output

local show_errors_silent = require'silent-commands'.show_errors

local spawn_console_window_silent = require'edvard_common'.spawn_console_window_silent

local show = require("edvard_common").show

local show_errors = require'edvard_common'.show_errors

local show_and_gather_err = require'edvard_common'.show_and_gather_err

local mysplit = require'edvard_common'.mysplit

local inside_traceback = false

failed_message = ""

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

run_lua = function(instructions, i)
  local input = instructions[i]
  setmetatable(input, {__index={cmd_description = "Build"}})
  local command, cmd_description =
    input[2],
    input[3] or input.cmd_description
  print("Starting " .. cmd_description .. "...")
  command()
  print(cmd_description .. " succeeded")
  if i < #instructions then
    coordinate_job_rec(instructions, i + 1)
  end
end


coordinate_job_rec = function(instructions, i)
  local job_type = instructions[i][1]
  if job_type == "silent" then
    run_silent_rec(instructions, i)
  elseif job_type == "hidden-scratch" then
    jobstart_hidden_scratch_rec(instructions, i)
  elseif job_type == "lua" then
    run_lua(instructions, i)
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

local write_console = function(run_dir, bufnr)
  if run_dir ~= nil then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    local contents = table.concat(lines, "\n")
    separator = package.config:sub(1,1)
    file = io.open(run_dir .. separator .. "Console.txt", "w")
    file:write(contents)
    file:close()
    print("contents written to Console.txt")
  end
end

jobstart_hidden_scratch_rec_original = function(instructions, i)
  local input = instructions[i]
  local has_stderr = false
  setmetatable(input, {__index={cmd_description = "Build" }})
  local command, error_keywords, cmd_description, run_dir, bufnr, promt_win  =
    input[2],
    input[3],
    input[4] or input.cmd_description,
    input[5] or nil,
    input[6],
    input[7]
  print("Starting " .. cmd_description .. "...")
  -- vim.cmd('echom  "' .. cmd_description .. '"...')
  local err_output = {}
  inside_traceback = false
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      show(data, bufnr, prompt_win)
    end,
    on_stderr = function(_, data)
      if not (#data == 1 and data[1] == "") then
        has_stderr = true
        err_output = show_and_gather_err(data, err_output, bufnr, prompt_win)
      end
    end,
    on_exit = function(_, exit_code, _)
      write_console(run_dir, bufnr)
      if #err_output > 0 then
        local transformed_errors = transform_errors(err_output)
        show_errors(transformed_errors, bufnr, prompt_win)
      end
      if has_stderr then
        print(cmd_description .. " failed" .. ", errors written to quickfix")
      elseif i < #instructions then
        coordinate_job_rec(instructions, i + 1)
      else
        show({"Done."}, bufnr, prompt_win)
        print(cmd_description .. " succeeded!")
      end
    end
  })
end

local filter_data = function(a_table, pattern_table)
  local out = {}
  local pattern_found = false
  for k, v in ipairs(a_table) do
    if v ~= nil then
      for _, single_pattern in ipairs(pattern_table) do
        if v:find(single_pattern) then
          pattern_found = true
        end
      end
      if not pattern_found then
          table.insert(out, v)
      end
      pattern_found = false
    end
  end
  return out
end


jobstart_hidden_scratch_rec = function(instructions, i)
  local input = instructions[i]
  local has_stderr = false
  setmetatable(input, {__index={cmd_description = "Build" }})
  local command, error_keywords, cmd_description, run_dir, extract_stacktraces, bufnr, promt_win   =
    input[2],
    input[3],
    input[4] or input.cmd_description,
    input[5] or nil,
    input[6] or nil,
    input[7],
    input[8]
  print("Starting " .. cmd_description .. "...")
  -- vim.cmd('echom  "' .. cmd_description .. '"...')
  -- Astrego specific code. Move
  local filter_table = { "sqlite3%.Cursor", "sqlite3%.Connection" }
  local err_output = {}
  local found_errors = false
  inside_traceback = false
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if extract_stacktraces then
        found_errors, err_output = extract_stacktraces(data, err_output)
        if found_errors then
          has_stderr = true
        end
      end
      filtered_data = filter_data(data, filter_table)
      show(filtered_data, bufnr, prompt_win)
    end,
    on_stderr = function(_, data)
      if not (#data == 1 and data[1] == "") then
        -- Astrego specific code
        if not data[1]:find("findfont") then
          has_stderr = true
          filtered_data = filter_data(data, filter_table)
          err_output = show_and_gather_err(filtered_data, err_output, bufnr, prompt_win)
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      write_console(run_dir, bufnr)
      if #err_output > 0 then
        local transformed_errors = transform_errors(err_output)
        show_errors(transformed_errors, bufnr, prompt_win)
      end
      if has_stderr then
        print(cmd_description .. " failed" .. ", errors written to quickfix")
        failed_message = cmd_description .. " failed" .. ", errors written to quickfix"
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
  failed_message = ""
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
  if not (failed_message == "") then
    print(failed_message)
  end
end

return M
