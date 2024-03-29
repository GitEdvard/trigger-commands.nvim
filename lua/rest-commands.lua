local M = {}

local spawn_scratch_window = require'common'spawn_scratch_window

local show_and_gather_err = require'common'show_and_gather_err

local show = require'common'show

local show_errors = require'common'show_errors

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

M.generate_command = function(run_settings)
    local command_candidate = {}
    table.insert(command_candidate, run_settings.type)
    table.insert(command_candidate, run_settings.program)
    if run_settings['args'] == nil then
        run_settings.args = {}
    end
    for _, v in ipairs(run_settings.args) do
        table.insert(command_candidate, v)
    end
    local command = vim.tbl_map(expand_values, command_candidate)
    return command
end

M._generate_command_multi = function(run_settings)
    local commands = {}
    for _, setting in ipairs(run_settings) do
        table.insert(commands, M.generate_command(setting))
    end
    return commands
end

local wrap_command = function(command)
    local command_str = table.concat(command, " ") .. "\n"
    return command_str
end

local generate_rest_command = function(command)
    local command_str = wrap_command(command)
    local first_part = [[
    max_attemts=2
    attempts_counter=0
    ]]
    local second_part = [[
until [ $? -eq 0 ]; do
if [ ${attempts_counter} -eq ${max_attemts} ]; then
    exit
    fi
    attempts_counter=$((attempts_counter+1))
    sleep 0.5
    ]]
    local third_part = [[
    done
    ]]
    return first_part .. command_str .. second_part .. command_str .. third_part
end

local has_errors = function(err_output)
    for _, v in ipairs(err_output) do
        if v ~= nil and #v > 0 then
            return true
        end
    end
    return false
end


M.run_rest_call = function(run_settings)
    if run_settings == nil or next(run_settings) == nil then
        error('run settings is empty')
    end
    local commands = M._generate_command_multi(run_settings)
    if #commands ~= 2 then
        local found = #commands
        if found == 0 then found = 1 end
        error('For rest calls, 2 run-settings are expected! Found: ' .. found)
    end
    local bufnr, prompt_win = spawn_scratch_window()
    local server_command = commands[1]
    local rest_command = generate_rest_command(commands[2])
    local err_output = {}
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Waiting for script output ..."})
    local server_job_id = vim.fn.jobstart(server_command, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            show(data, bufnr, prompt_win)
        end,
        on_stderr = function(_, data)
            err_output = show_and_gather_err(data, err_output, bufnr, prompt_win)
        end,
        on_exit = function(_, exit_code, _)
            if has_errors(err_output) then
                show_errors(err_output, bufnr, prompt_win)
            end
        end
    })
    vim.fn.jobstart(rest_command, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            show(data, bufnr, prompt_win)
        end,
        on_exit = function(_, _, _)
            vim.fn.jobstop(server_job_id)
        end
    })
end

return M
