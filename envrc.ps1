$ZigVersion = "0.16.0"
$ZigPlatform = "x86_64-windows"
$ZigDist = "zig-$ZigPlatform-$ZigVersion"

$BaseDir = Resolve-Path "."
$ZigDir = Join-Path $BaseDir ".direnv\$ZigDist"
$ZigZipPath = Join-Path $BaseDir ".direnv\$ZigDist.zip"

if (-not (Test-Path $ZigDir))
{
  New-Item -ItemType Directory -Path "$BaseDir\.direnv" -Force | Out-Null
  Invoke-WebRequest "https://ziglang.org/download/$ZigVersion/$ZigDist.zip" -OutFile $ZigZipPath
  Expand-Archive $ZigZipPath -DestinationPath "$BaseDir\.direnv\" -Force
  Remove-Item $ZigZipPath
}

$env:PATH = "$ZigDir;$env:PATH"
