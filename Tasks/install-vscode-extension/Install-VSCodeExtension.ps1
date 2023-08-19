<#
.SYNOPSIS
    Install an extension defined by the given item name to Visual Studio Code
.PARAMETER MarketplaceItemName 
    Markplace Item Name (as used in the URI of a given Visual Studio Extension Maketplace entry)
#>
param (
        [Parameter(Mandatory)]
        [string]$MarketplaceItemName
    )

<#
.SYNOPSIS
    Installs an extension defined by the given item name
.PARAMETER MarketplaceItemName 
    Markplace Item Name (as used in the URI of a given Visual Studio Code Extension Maketplace entry)
#>

function Test-IsOsArchX64 {
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        return (Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture -match '64'
    }

    return [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::X64
}


function Get-CodePlatformInformation {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('32-bit', '64-bit')]
        [string]
        $Bitness,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Stable-System', 'Stable-User', 'Insider-System', 'Insider-User')]
        [string]
        $BuildEdition
    )

    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        $os = 'Windows'
    }
    elseif ($IsLinux) {
        $os = 'Linux'
    }
    elseif ($IsMacOS) {
        $os = 'MacOS'
    }
    else {
        throw 'Could not identify operating system'
    }

    if ($Bitness -ne '64-bit' -and $os -ne 'Windows') {
        throw "Non-64-bit *nix systems are not supported"
    }

    if ($BuildEdition.EndsWith('User') -and $os -ne 'Windows') {
        throw 'User builds are not available for non-Windows systems'
    }

    switch ($BuildEdition) {
        'Stable-System' {
            $appName = "Visual Studio Code ($Bitness)"
            break
        }

        'Stable-User' {
            $appName = "Visual Studio Code ($($Architecture) - User)"   
            break
        }

        'Insider-System' {
            $appName = "Visual Studio Code - Insiders Edition ($Bitness)"
            break
        }

        'Insider-User' {
            $appName = "Visual Studio Code - Insiders Edition ($($Architecture) - User)"
            break
        }
    }

    switch ($os) {
        'Linux' {
            $pacMan = Get-AvailablePackageManager

            switch ($pacMan) {
                'apt' {
                    $platform = 'linux-deb-x64'
                    $ext = 'deb'
                    break
                }

                { 'dnf','yum','zypper' -contains $_ } {
                    $platform = 'linux-rpm-x64'
                    $ext = 'rpm'
                    break
                }

                default {
                    $platform = 'linux-x64'
                    $ext = 'tar.gz'
                    break
                }
            }

            if ($BuildEdition.StartsWith('Insider')) {
                $exePath = '/usr/bin/code-insiders'
                break
            }

            $exePath = '/usr/bin/code'
            break
        }

        'MacOS' {
            $platform = 'darwin'
            $ext = 'zip'

            if ($BuildEdition.StartsWith('Insider')) {
                $exePath = '/usr/local/bin/code-insiders'
                break
            }

            $exePath = '/usr/local/bin/code'
            break
        }

        'Windows' {
            $ext = 'exe'
            switch ($Bitness) {
                '32-bit' {
                    $platform = 'win32'

                    if (Test-IsOsArchX64) {
                        $installBase = ${env:ProgramFiles(x86)}
                        break
                    }

                    $installBase = ${env:ProgramFiles}
                    break
                }

                '64-bit' {
                    $installBase = ${env:ProgramFiles}

                    if (Test-IsOsArchX64) {
                        $platform = 'win32-x64'
                        break
                    }

                    Write-Warning '64-bit install requested on 32-bit system. Installing 32-bit VSCode'
                    $platform = 'win32'
                    break
                }
            }

            switch ($BuildEdition) {
                'Stable-System' {
                    $exePath = "$installBase\Microsoft VS Code\bin\code.cmd"
                }

                'Stable-User' {
                    $exePath = "${env:LocalAppData}\Programs\Microsoft VS Code\bin\code.cmd"
                }

                'Insider-System' {
                    $exePath = "$installBase\Microsoft VS Code Insiders\bin\code-insiders.cmd"
                }

                'Insider-User' {
                    $exePath = "${env:LocalAppData}\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"
                }
            }
        }
    }

    switch ($BuildEdition) {
        'Stable-System' {
            $channel = 'stable'
            break
        }

        'Stable-User' {
            $channel = 'stable'
            $platform += '-user'
            break
        }

        'Insider-System' {
            $channel = 'insider'
            break
        }

        'Insider-User' {
            $channel = 'insider'
            $platform += '-user'
            break
        }
    }

    $info = @{
        AppName = $appName
        ExePath = $exePath
        Platform = $platform
        Channel = $channel
        FileUri = "https://update.code.visualstudio.com/latest/$platform/$channel"
        Extension = $ext
    }

    if ($pacMan) {
        $info['PackageManager'] = $pacMan
    }

    return $info
}

# ---- Main Script Start ----

# Declare exit code. Default to failure and set to 0 when operation succeeds.
$exitCode = 1

# Turn off progress to fix speed bug in Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

# Dev Box will always use 64-bit architecture. TODO: validate
$Architecture = '64-bit'

# TODO: is VS Code installed at system or user level?
# $BuildEdition = 'Stable-User'
$BuildEdition = 'Stable-Admin'

# Get information required for installation

Write-Host "Getting platform information..."

$codePlatformInfo = Get-CodePlatformInformation -Bitness $Architecture -BuildEdition $BuildEdition
$codeExePath = $codePlatformInfo.ExePath

Write-Host "Visual Studio Code found at $codeExePath"

# Install extension

try {
    Write-Host "`nInstalling extension $MarketplaceItemName..."
    & $codeExePath --install-extension $MarketplaceItemName
}
catch {
    Write-Warning "VSCode extension Installer failed with error: $_"
    exit $exitcode
}

Write-Host "VSCode extension Installer Completed."
Write-Host "$MarketplaceItemName Successfully installed."

$exitcode = 0
exit $exitCode

# ---- Main Script End ----