-- Install-LinuxTools: oh-my-posh prompt in cmd through clink.
-- clink loads this file from its state directory (%LOCALAPPDATA%\clink).
-- The theme is the one Install-LinuxTools.ps1 -WithOhMyPosh writes for PowerShell.
local theme_file = os.getenv('USERPROFILE') .. '\\.config\\oh-my-posh\\install-linuxtools.omp.json'

-- The volume label for the theme, "[MYDISK D:\]": the theme reads .Env.WLT_VOLLABEL.
-- This filter runs before the oh-my-posh one (priority 1 in its omp.lua; lower runs
-- first) and only sets the variable. clink has no function for a volume label, so
-- Windows PowerShell reads it, once per drive for this window. It prints the label
-- as hex UTF-8 bytes, so no console code page can spoil it.
local wlt_labels = {}
local function wlt_volume_label(drive)
  if wlt_labels[drive] == nil then
    wlt_labels[drive] = ''
    local cmd = 'powershell.exe -NoProfile -NonInteractive -Command "try { $l = ([IO.DriveInfo]::new(\'' .. drive ..
      '\\\')).VolumeLabel; -join ([Text.Encoding]::UTF8.GetBytes($l) | ForEach-Object { \'{0:x2}\' -f $_ }) } catch { }"'
    local h = io.popen(cmd)
    if h then
      local hex = (h:read('*a') or ''):match('^%s*(%x*)')
      h:close()
      wlt_labels[drive] = (hex or ''):gsub('%x%x', function(b) return string.char(tonumber(b, 16)) end)
    end
  end
  return wlt_labels[drive]
end
local wlt_filter = clink.promptfilter(-1)
function wlt_filter:filter(prompt)
  local drive = (os.getcwd() or ''):match('^(%a:)')
  local label = drive and wlt_volume_label(drive:upper()) or ''
  os.setenv('WLT_VOLLABEL', label ~= '' and label or nil)
end

load(io.popen('oh-my-posh init cmd --config "' .. theme_file .. '"'):read("*a"))()
