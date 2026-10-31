-- Install-LinuxTools: oh-my-posh prompt in cmd through clink.
-- clink loads this file from its state directory (%LOCALAPPDATA%\clink).
-- The theme is the one Install-LinuxTools.ps1 -WithOhMyPosh writes for PowerShell.
local theme_file = os.getenv('USERPROFILE') .. '\\.config\\oh-my-posh\\install-linuxtools.omp.json'

load(io.popen('oh-my-posh init cmd --config "' .. theme_file .. '"'):read("*a"))()
