#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$NdkVersion = "29.0.14206865"
)
$ErrorActionPreference = "Stop"
$sdkManager = Join-Path $SdkRoot "cmdline-tools\latest\bin\sdkmanager.bat"
if (-not (Test-Path $sdkManager)) { throw "Android SDK manager not found: $sdkManager" }
Write-Host "Installing side-by-side Android NDK $NdkVersion into $SdkRoot"
# cmd.exe is used so the semicolon in the Android SDK package name is not parsed by PowerShell.
$cmd = "`"$sdkManager`" --sdk_root=`"$SdkRoot`" --install `"ndk;$NdkVersion`""
cmd.exe /d /s /c $cmd
if ($LASTEXITCODE -ne 0) { throw "sdkmanager failed with exit code $LASTEXITCODE" }
$ndk = Join-Path $SdkRoot "ndk\$NdkVersion"
$compiler = Join-Path $ndk "toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android31-clang.cmd"
if (-not (Test-Path $compiler)) { throw "NDK installed but API 31 compiler not found: $compiler" }
Write-Host "NDK ready at $ndk"
Write-Host "NOTE: PanVK host tools still require Linux/WSL."
