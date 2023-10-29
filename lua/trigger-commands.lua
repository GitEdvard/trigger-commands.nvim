local M = {}

M.run_multi = function(commands)
  require'scratch-commands'.run_multi(commands)
end

M.run_single = function(command)
  require'scratch-commands'.run_single(command)
end

M.run_launcher = function(command, error_keyword)
  require'scratch-commands'.run_launcher(command, error_keyword)
end

M.run_rest_call = function(run_settings)
  require'rest-commands'.run_rest_call(run_settings)
end

M.run_silent = function(input)
  require'silent-commands'.run_silent(input)
end

M.generate_command = function(run_settings)
  require'rest-commands'.generate_command(run_settings)
end

return M
