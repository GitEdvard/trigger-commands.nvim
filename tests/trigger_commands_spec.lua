-- :PlenaryBustedDirectory %
describe('trigger_commands', function()
    it('can generate command from table without keywords', function()
        local run_settings = {
            type = "python",
            command = "somefile.py",
            args = { "switch1", "value1" }
        }
        local command = require'trigger-commands'._generate_command(run_settings)
        local expected = {
            "python", "somefile.py", "switch1", "value1"
        }
        assert.are.same(expected, command)
    end)
    it('can generate command from table with keywords', function()
        local run_settings = {
            type = "python",
            command = "somefile.py",
            args = { "switch1", "${env:MYVAR}" }
        }
        vim.cmd(":let $MYVAR = 'value2'")
        local command = require'trigger-commands'._generate_command(run_settings)
        local expected = {
            "python", "somefile.py", "switch1", "value2"
        }
        assert.are.same(expected, command)
    end)
    it('table with no args', function()
        local run_settings = {
            type = "python",
            command = "somefile.py",
        }
        vim.cmd(":let $MYVAR = 'value2'")
        local command = require'trigger-commands'._generate_command(run_settings)
        local expected = {
            "python", "somefile.py"
        }
        assert.are.same(expected, command)
    end)
    it('can read multi command table', function()
        local run_settings = {
            {
                type = "python",
                command = "somefile.py",
            },
            {
                type = "python",
                command = "someotherfile.py",
            }
        }
        local command = require'trigger-commands'._generate_command_multi(run_settings)
        local expected = {
            {"python", "somefile.py"},
            {"python", "someotherfile.py"},
        }
        assert.are.same(expected, command)

    end)
end)
