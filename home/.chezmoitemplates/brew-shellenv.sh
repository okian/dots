# Make brew available in this script (paths differ by OS/arch). Shared snippet
# included by the run_*.sh.tmpl scripts via chezmoi's template directive.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  [ -x "$_brew" ] && eval "$("$_brew" shellenv)" && break
done
unset _brew
