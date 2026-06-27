-- LazyVim loads this on startup. Add your option overrides here.
-- (number/relativenumber/wrap/confirm/undofile already match LazyVim defaults.)
local opt = vim.opt

opt.scrolloff = 8 -- keep 8 lines of context above/below the cursor (LazyVim: 4)

-- Kill all snacks animation (scroll, dim, etc.) — the canonical LazyVim switch.
-- Scrolling is instant and nothing animates the viewport.
vim.g.snacks_animate = false

-- Persistent ("infinite") undo + keep swap/backup files OUT of the edited
-- file's directory. All state lives under Neovim's state dir.
local state = vim.fn.stdpath("state")
local undodir = state .. "/undo"
local backupdir = state .. "/backup"
local swapdir = state .. "/swap"
for _, dir in ipairs({ undodir, backupdir, swapdir }) do
  vim.fn.mkdir(dir, "p")
end

opt.undolevels = 100000        -- effectively unlimited in-memory undo (LazyVim: 10000)
opt.undoreload = 100000        -- keep undo when reloading large files
opt.undodir = undodir

-- No PERMANENT backups: infinite undofile above + git everywhere already cover
-- recovery. Keep only the transient write-backup (atomic saves, on by default)
-- and swap, both routed out of the working dir via these state dirs.
opt.backupdir = backupdir
opt.directory = swapdir
