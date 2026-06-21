-- LazyVim loads this on startup. Add your option overrides here.
local opt = vim.opt

opt.relativenumber = true
opt.number = true
opt.scrolloff = 8
opt.wrap = false
opt.confirm = true

-- Persistent ("infinite") undo + keep backup/swap/undo files OUT of the
-- edited file's directory. All state lives under Neovim's state dir.
local state = vim.fn.stdpath("state")
local undodir = state .. "/undo"
local backupdir = state .. "/backup"
local swapdir = state .. "/swap"
for _, dir in ipairs({ undodir, backupdir, swapdir }) do
  vim.fn.mkdir(dir, "p")
end

opt.undofile = true            -- persist undo history across sessions
opt.undolevels = 100000        -- effectively unlimited in-memory undo
opt.undoreload = 100000        -- keep undo when reloading large files
opt.undodir = undodir

opt.backup = true              -- keep a backup after writing
opt.writebackup = true
-- No "." entries -> backups/swap are never written next to the real file.
opt.backupdir = backupdir
opt.directory = swapdir
