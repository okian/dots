-- Custom keymaps (loaded by LazyVim after its defaults). Managed by chezmoi.
--
-- Television (`tv`) integration — the same fuzzy finder used in the shell, as a
-- terminal-style picker inside Neovim. LazyVim's snacks.picker remains the
-- primary in-editor finder (<leader>f…/<leader>s…); these give the tv UI for
-- muscle memory and tv's channels. Runs tv in a floating terminal, captures the
-- selection, and opens it. No-ops with a notice if `tv` isn't on PATH.

local function open_float(buf)
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.85)
  return vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " television ",
    title_pos = "center",
  })
end

-- Run `tv <args>`, send the chosen line(s) to `on_pick(selection_list)`.
local function tv_run(args, on_pick)
  if vim.fn.executable("tv") == 0 then
    vim.notify("television (`tv`) not found on PATH", vim.log.levels.WARN, { title = "tv" })
    return
  end
  local tmp = vim.fn.tempname()
  local cmd = { "sh", "-c", "tv " .. args .. " > " .. vim.fn.shellescape(tmp) }
  local buf = vim.api.nvim_create_buf(false, true)
  local win = open_float(buf)

  local function finish()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    local sel = {}
    local f = io.open(tmp, "r")
    if f then
      for line in f:lines() do
        if #line > 0 then
          table.insert(sel, line)
        end
      end
      f:close()
    end
    os.remove(tmp)
    if #sel > 0 then
      vim.schedule(function()
        on_pick(sel)
      end)
    end
  end

  -- Prefer the modern jobstart terminal API (nvim 0.11+); fall back to termopen.
  if vim.fn.has("nvim-0.11") == 1 then
    vim.fn.jobstart(cmd, { term = true, on_exit = finish })
  else
    vim.fn.termopen(cmd, { on_exit = finish })
  end
  vim.cmd("startinsert")
end

-- Open each selected file in the editor.
local function edit_files(sel)
  for _, file in ipairs(sel) do
    vim.cmd("edit " .. vim.fn.fnameescape(file))
  end
end

-- Selection from the `text` channel looks like `path:line:col:...`; jump there.
local function edit_at_location(sel)
  local entry = sel[1]
  local file, lnum = entry:match("^(.-):(%d+):")
  if file then
    vim.cmd("edit " .. vim.fn.fnameescape(file))
    vim.api.nvim_win_set_cursor(0, { tonumber(lnum), 0 })
    vim.cmd("normal! zz")
  else
    edit_files({ entry })
  end
end

vim.keymap.set("n", "<leader>tv", function()
  tv_run("files", edit_files)
end, { desc = "Television: find files" })

vim.keymap.set("n", "<leader>tw", function()
  tv_run("text", edit_at_location)
end, { desc = "Television: grep text" })
