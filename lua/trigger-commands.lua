local M = {}

M.run_multi = function(commands)
  require'scratch-commands'.run_multi(commands)
end

M.run_single = function(command)
  require'scratch-commands'.run_single(command)
end

M.run_rest_call = function(run_settings)
  require'rest-commands'.run_rest_call(run_settings)
end

return M
