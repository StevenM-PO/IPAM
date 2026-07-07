# Puts the project-local portable Node.js on PATH for this shell, then runs the rest
# of the line as a command. Usage:  .\frontend-dev.ps1 npm run dev
$nodeDir = (Get-ChildItem "$PSScriptRoot\.nodedev" -Directory | Where-Object { $_.Name -like 'node-*' })[0].FullName
$env:Path = "$nodeDir;$env:Path"
if ($args.Count -gt 0) { & $args[0] @($args[1..($args.Count-1)]) }
