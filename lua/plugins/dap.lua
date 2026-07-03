-- lua/plugins/dap.lua
-- Debug Adapter Protocol client, wired for .NET (F#/C#) via netcoredbg
-- (install with :MasonInstall netcoredbg; exepath fallback below also
-- finds a manually installed binary).
--
-- Keymaps use function keys: a <leader>d* family would stall the
-- single-char <leader>d (delete to black hole) for timeoutlen on every
-- press — the exact class of collision this config already eliminated.
return {
  {
    "mfussenegger/nvim-dap",
    keys = {
      {
        "<F5>",
        function() require("dap").continue() end,
        desc = "DAP continue/launch",
      },
      {
        "<F9>",
        function() require("dap").toggle_breakpoint() end,
        desc = "DAP toggle breakpoint",
      },
      {
        "<F10>",
        function() require("dap").step_over() end,
        desc = "DAP step over",
      },
      {
        "<F11>",
        function() require("dap").step_into() end,
        desc = "DAP step into",
      },
      {
        "<F12>",
        function() require("dap").step_out() end,
        desc = "DAP step out",
      },
    },
    config = function()
      local dap = require("dap")

      local function netcoredbg_path()
        local mason = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg"
        if vim.fn.executable(mason) == 1 then
          return mason
        end
        return vim.fn.exepath("netcoredbg")
      end

      dap.adapters.coreclr = function(callback)
        local cmd = netcoredbg_path()
        if cmd == "" then
          vim.notify(
            "netcoredbg not found — :MasonInstall netcoredbg",
            vim.log.levels.ERROR
          )
          return
        end
        callback({
          type = "executable",
          command = cmd,
          args = { "--interpreter=vscode" },
        })
      end

      local launch = {
        {
          type = "coreclr",
          name = "Launch DLL (netcoredbg)",
          request = "launch",
          program = function()
            return vim.fn.input(
              "Path to dll: ",
              vim.fn.getcwd() .. "/bin/Debug/",
              "file"
            )
          end,
        },
      }
      dap.configurations.fsharp = launch
      dap.configurations.cs = launch

      vim.fn.sign_define(
        "DapBreakpoint",
        { text = "●", texthl = "DiagnosticError" }
      )
      vim.fn.sign_define(
        "DapStopped",
        { text = "▶", texthl = "DiagnosticWarn", linehl = "CursorLine" }
      )
    end,
  },
}
