#Requires -Version 5.1

<#
.SYNOPSIS
    Install a selection of mods for Lethal Company.

.DESCRIPTION
    This script installs a selection of mods for Lethal Company defined in a preset.

.EXAMPLE
    PS> ./LethalCompanyModder.ps1

    Install mods for Lethal Company.

.NOTES
    This script assumes that your installation of Lethal Company is managed by Steam on Windows.
    It also installs BepInEx plugin framework, as some mods are BepInEx plugins.

.LINK
    - BepInEx GitHub repository: https://github.com/BepInEx/BepInEx
    - BepInEx installation guide: https://docs.bepinex.dev/articles/user_guide/installation/index.html
    - Thunderstore API documentation: https://thunderstore.io/api/docs/
    - Lethal Company community page on Thunderstore: https://thunderstore.io/c/lethal-company/

#>

[CmdletBinding(DefaultParameterSetName = "Curated")]
param (
    [Parameter(
        HelpMessage = "Specify this parameter if you intend to host the game (server)"
    )]
    [Alias("Server")]
    [switch] $ServerHost,

    [Parameter(
        HelpMessage = "Name of the preset of mods to install"
    )]
    [string] $Preset = "Default",

    [Parameter(
        ParameterSetName = "Curated",
        HelpMessage = "Name of the Git branch where the curated preset of mods is located"
    )]
    [string] $GitBranch = "main",

    [Parameter(
        ParameterSetName = "Custom",
        HelpMessage = "Path to a JSON file including the preset of mods to install"
    )]
    [ValidateScript({ if (Test-Path -Path $_ -PathType Leaf) { $true } else { throw "`"$_`" file not found." } })]
    [string] $File,

    [Parameter(
        HelpMessage = "Upgrade everything but keep the existing configuration"
    )]
    [ValidateScript({ if ($Force.IsPresent) { throw "Cannot use Upgrade and Force parameters at the same time." } else { $true } })]
    [Alias("Update")]
    [switch] $Upgrade,

    [Parameter(
        HelpMessage = "Proceed to clean installation"
    )]
    [ValidateScript({ if ($Upgrade.IsPresent) { throw "Cannot use Upgrade and Force parameters at the same time." } else { $true } })]
    [switch] $Force
)

#region ---- System and PowerShell configuration and pre-flight check
# Set PowerShell Cmdlet
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # Fix slow execution for some cmdlets
if ($PSBoundParameters.Debug -and $PSEdition -eq "Desktop") {
    # Fix repetitive action confirmation in PowerShell Desktop when Debug parameter is set
    $DebugPreference = "Continue"
}

# Check if system is running on Windows
if ($env:OS -notmatch "Windows") { Write-Error -Message "Cannot run as it supports Windows only." }
#endregion ----

#region ---- Define helper functions
function New-TemporaryDirectory {
    # Create a new temporary directory and return its path
    [CmdletBinding()]
    param ()

    process {
        $RandomString = -join ((97..122) | Get-Random -Count 8 | ForEach-Object -Process { [char]$_ })
        New-Item -Path $env:TEMP -Name "LethalCompanyModder-$RandomString" -ItemType Directory | Select-Object -ExpandProperty FullName
    }
}

function Invoke-PackageDownloader {
    # Download and extract a package in a temporary directory and return its path
    [CmdletBinding()]
    param (
        [string] $Url
    )

    process {
        $TemporaryDirectory = New-TemporaryDirectory
        try {
            Write-Debug -Message "Download package archive from `"$Url`"."
            Invoke-WebRequest -Uri $Url -OutFile "$TemporaryDirectory\package.zip"
            Write-Debug -Message "Extract package archive to temporary directory `"$TemporaryDirectory`"."
            Expand-Archive -Path "$TemporaryDirectory\package.zip" -DestinationPath $TemporaryDirectory
            Remove-Item -Path "$TemporaryDirectory\package.zip"
        }
        catch {
            Remove-Item -Path $TemporaryDirectory -Recurse
            Write-Error -Message "An error occured with package downloader: {0}" -f $_.Exception.Message
        }
        $TemporaryDirectory
    }
}

function Invoke-StartWaitStopProcess {
    # Start, wait and stop process
    [CmdletBinding()]
    param (
        [string] $Executable,
        [string] $ProcessName,
        [int] $Seconds = 10
    )

    Write-Debug -Message "Start `"$Executable`" and wait."
    Start-Process -FilePath $Executable -WindowStyle Hidden
    Start-Sleep -Seconds $Seconds
    Write-Debug -Message "Stop `"$ProcessName`" process and wait."
    Stop-Process -Name $ProcessName -Force
    Start-Sleep -Seconds 1
}
#endregion ----

#region ---- Definition of mods for Lethal Company
$ModsData = $(switch ($PSCmdlet.ParameterSetName) {
        "Curated" {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/fscorrupt/LethalCompanyModder/$GitBranch/mods.json" | Select-Object -ExpandProperty Content
        }
        "Custom" {
            Get-Content -Path $File -Raw
        }
    }) | ConvertFrom-Json
$SelectedMods = $ModsData.Presets | Select-Object -ExpandProperty $Preset
if (-not $SelectedMods) {
    Write-Error -Message "No mod to install. Preset `"$Preset`" is empty or does not exist."
}
$Mods = $ModsData.Mods | Where-Object -Property Name -In -Value $SelectedMods

# If ServerHost parameter is not present, exclude mods that are only required by server host
if (-not $ServerHost.IsPresent) {
    $Mods = $Mods | Where-Object -Property "ServerHostOnly" -NE -Value $true
}
#endregion ----

#region ---- Installation of mods for Lethal Company
$Banner = @"

  ##################################################################################
  ##                                                                              ##
 ###    ###        #######   #########   ###    ###        ###       ###          ##
 ###    ###        ###         ####      ###    ###       #####       ###         ##
 ###   ###        ####         ####      ##########      #######      ###         ###
 ###   ###        ########     ####      ##########     #### ####     ###         ###
 ###  ###         ###          ####      ###    ###    ###########    ###         ###
 ### ##########   ########     ####      ###    ###   #####   #####    #########  ###
 ##                                                                                ##
###    #####    ######   #####    ##### #######     #####   ####    #######   #### ###
### ######### ########## ######  ###### #########  ######   #####   ########  #### ###
## #####     ####    ### ######  ###### ###  ####  #######  ####### #### #######   ###
## ####      ###     ### ############## ######### #### #### ############  ######   ###
## #####     ####    ### ### ########## #######  ########## #### #######   ####     ##
##  ######### ########## ### ##### #### ###     ################  ######   ###      ##
##    ######    ######   ###  ###   ### ###     ####    ########    ####   ###      ##
##                                                                                  ##
######################################################################################

Our auto-pilot is going to install a selection of high-end mods for you (and the Company).
In the meantime, just seat back and relax...

Mods to be installed:
{0}

"@ -f (($Mods | ForEach-Object -Process { " o {0}: {1}" -f $_.DisplayName, $_.Description }) -join "`r`n")
Write-Host $Banner -ForegroundColor Green

Write-Host "Installation of Lethal Company mods started." -ForegroundColor Cyan
if ($Upgrade.IsPresent) { Write-Host "This runs in upgrade mode." -ForegroundColor Cyan }

# Search for directory where Lethal Company is installed
Write-Host "Search for Lethal Company installation directory."
$DriveRootPaths = Get-PSDrive -PSProvider FileSystem | Where-Object -Property "Name" -NE -Value "Temp" | Select-Object -ExpandProperty Root
$PredictPaths = @(
    "Program Files (x86)\Steam\steamapps\common"  # Default Steam installation path for games
    "Program Files\Steam\steamapps\common"
    "SteamLibrary\steamapps\common"
    "Steam\SteamLibrary\steamapps\common"
) | ForEach-Object -Process { foreach ($p in $DriveRootPaths) { Join-Path -Path $p -ChildPath $_ } }
$ChildItemParams = @{
    Path   = $PredictPaths + $DriveRootPaths  # Respect order to check every path prediction first
    Filter = "Lethal Company"
}
$GameDirectory = Get-ChildItem @ChildItemParams -Directory -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 1
if (-not $GameDirectory) { Write-Error -Message "Lethal Company installation directory not found." }
Write-Debug -Message "Lethal Company directory found `"$GameDirectory`"."
try { $GameExecutable = Join-Path -Path $GameDirectory -ChildPath "Lethal Company.exe" -Resolve }
catch { Write-Error -Message "Lethal Company executable not found in directory `"$GameDirectory`"." }
Write-Debug -Message "Lethal Company executable found `"$GameExecutable`"."

# Define BepInEx structure
$BepInEx = @{
    RootDirectory     = "$GameDirectory\BepInEx"
    CoreDirectory     = "$GameDirectory\BepInEx\core"
    ConfigDirectory   = "$GameDirectory\BepInEx\config"
    ConfigFile        = "$GameDirectory\BepInEx\config\BepInEx.cfg"
    PluginsDirectory  = "$GameDirectory\BepInEx\plugins"
    PatchersDirectory = "$GameDirectory\BepInEx\patchers"
    LogFile           = "$GameDirectory\BepInEx\LogOutput.log"
    WinhttpDll        = "$GameDirectory\winhttp.dll"
    DoorstopConfigIni = "$GameDirectory\doorstop_config.ini"
}

if (Test-Path -Path $BepInEx.RootDirectory) {
    if (-not $Upgrade.IsPresent) {
        if (-not $Force.IsPresent) {
            Write-Error -Message "BepInEx directory already exist. Please, run the script in upgrade mode or force the re-installation."
        }
    }

    # Backup BepInEx directory
    Write-Host "Backup BepInEx directory."
    $BackupParams = @{
        Path            = $BepInEx.RootDirectory
        DestinationPath = "{0}_Backup.zip" -f $BepInEx.RootDirectory
    }
    Write-Debug -Message ("Backup existing BepInEx directory to `"{0}`"." -f $BackupParams.DestinationPath)
    Compress-Archive @BackupParams -Force

    # Remove existing BepInEx components from Lethal Company directory
    Write-Host "Clean BepInEx files and directory up."
    $ItemsToRemove = if ($Upgrade.IsPresent) {
        @(
            $BepInEx.CoreDirectory
            $BepInEx.PluginsDirectory
            $BepInEx.PatchersDirectory
            $BepInEx.LogFile
            $BepInEx.WinhttpDll
            $BepInEx.DoorstopConfigIni
        )
    }
    else {
        @(
            $BepInEx.RootDirectory
            $BepInEx.WinhttpDll
            $BepInEx.DoorstopConfigIni
        )
    }
    $ItemsToRemove | ForEach-Object -Process {
        if (Test-Path -Path $_) {
            Write-Debug -Message "Remove existing BepInEx component `"$_`"."
            Remove-Item -Path $_ -Recurse -Force
        }
    }
}

# Install BepInEx from GitHub
Write-Host "Install BepInEx plugin framework."
$DownloadUrl = (Invoke-RestMethod -Uri "https://api.github.com/repos/BepInEx/BepInEx/releases/latest")."assets"."browser_download_url" | Select-String -Pattern ".*\/BepInEx_x64_.*.zip"
if (-not $DownloadUrl) { Write-Error -Message "BepInEx download URL not found." }
try {
    $TempPackage = Invoke-PackageDownloader -Url $DownloadUrl
    Write-Debug -Message "Copy BepInEx package to `"$GameDirectory`"."
    Copy-Item -Path "$TempPackage\*" -Destination $GameDirectory -Exclude "changelog.txt" -Recurse -Force
}
finally { if ($TempPackage) { Remove-Item -Path $TempPackage -Recurse } }

# Run Lethal Company executable to generate BepInEx configuration files
Write-Host "Launch Lethal Company to install BepInEx."
Invoke-StartWaitStopProcess -Executable $GameExecutable -ProcessName "Lethal Company"

# Check if BepInEx files have been successfully generated
Write-Host "Validate BepInEx installation."
$BepInEx.ConfigFile, $BepInEx.LogFile | ForEach-Object -Process {
    if (Test-Path -Path $_) { Write-Debug -Message "BepInEx file `"$_`" found." }
    else { Write-Error -Message "BepInEx installation failed because `"$_`" not found." }
}

# Install Mods from Thunderstore
$ThunderstoreMods = $Mods | Where-Object -Property "Provider" -EQ -Value "Thunderstore"
foreach ($mod in $ThunderstoreMods) {
    Write-Host ("       Install {0} mod by {1}." -f $mod.DisplayName, $mod.Namespace)
    $FullName = "{0}/{1}" -f $mod.Namespace, $mod.Name
    $DownloadUrl = (Invoke-RestMethod -Uri "https://thunderstore.io/api/experimental/package/$FullName/")."latest"."download_url"
    if (-not $DownloadUrl) { Write-Error -Message "$FullName mod download URL was not found." }
    try {
        $TempPackage = Invoke-PackageDownloader -Url $DownloadUrl
        switch ($mod.Type) {
            "BepInExPlugin" {
                Write-Debug -Message ("{0} {1}: Copy DLL files to `"{2}`"." -f $mod.Type, $FullName, $BepInEx.PluginsDirectory)
                Get-ChildItem -Path "$TempPackage\*" -Include "*.dll" -Recurse | Move-Item -Destination $BepInEx.PluginsDirectory
                foreach ($item in $mod.ExtraIncludes) {
                    $Path = Join-Path -Path $TempPackage -ChildPath $item
                    Write-Debug -Message ("{0} {1}: Copy `"{2}`" to `"{3}`"." -f $mod.Type, $FullName, $item, $BepInEx.PluginsDirectory)
                    Move-Item -Path $Path -Destination $BepInEx.PluginsDirectory
                }
            }
            "BepInExPatcher" {
                Write-Debug -Message ("{0} {1}: Copy DLL files to `"{2}`"." -f $mod.Type, $FullName, $BepInEx.PatchersDirectory)
                Get-ChildItem -Path "$TempPackage\*" -Include "*.dll" -Recurse | Move-Item -Destination $BepInEx.PatchersDirectory
                Write-Debug -Message ("{0} {1}: Copy CFG files to `"{2}`"." -f $mod.Type, $FullName, $BepInEx.ConfigDirectory)
                Get-ChildItem -Path "$TempPackage\*" -Include "*.cfg" -Recurse | ForEach-Object -Process {
                    $Path = Join-Path -Path $BepInEx.ConfigDirectory -ChildPath $_.Name
                    if (-not (Test-Path -Path $Path)) {
                        Move-Item -Path $_.FullName -Destination $BepInEx.ConfigDirectory
                    }
                }
            }
            Default { Write-Warning -Message ("Unknown `"{0}`" mod type for {1}. Skip." -f $mod.Type, $FullName) }
        }
    }
    finally { if ($TempPackage) { Remove-Item -Path $TempPackage -Recurse } }
}

Write-Host "Installation of Lethal Company mods completed." -ForegroundColor Cyan

# Edit config file
$ConfigFileName = "RickArg.lethalcompany.helmetcameras.cfg"
$ConfigPath = $BepInEx.ConfigDirectory + "\" + $ConfigFileName

Write-Host "        Now lets modify the config file: $ConfigFileName"

# Read the content of the file
if (Test-Path $ConfigPath) {
    $fileContent = Get-Content $ConfigPath -Raw
}
Else {
    $Content = @"
## Settings file was created by plugin Helmet_Cameras v2.1.4
## Plugin GUID: RickArg.lethalcompany.helmetcameras

[MONITOR QUALITY]

## Low FPS affection. High Quality mode. 0 - vanilla (48x48), 1 - vanilla+ (128x128), 2 - mid quality (256x256), 3 - high quality (512x512), 4 - Very High Quality (1024x1024)
# Setting type: Int32
# Default value: 0
monitorResolution = 4

## Low FPS affection. Render distance for helmet camera.
# Setting type: Int32
# Default value: 20
renderDistance = 25

## Very high FPS affection. FPS for helmet camera. To increase YOUR fps, you should low cameraFps value.
# Setting type: Int32
# Default value: 30
cameraFps = 30
"@
    $content | Out-File  $ConfigPath -Force
    Start-Sleep 2
    $content | Set-Content $ConfigPath
    $fileContent = Get-Content $ConfigPath -Raw
}

# Use regular expressions to find and replace the values
$fileContent = $fileContent -replace '(?<=monitorResolution = )\d+', '4'
$fileContent = $fileContent -replace '(?<=renderDistance = )\d+', '25'

# Write the modified content back to the file
$fileContent | Set-Content $ConfigPath

# Check if the changes were successful
$updatedContent = Get-Content $ConfigPath -Raw
$monitorResolution = [regex]::Match($updatedContent, '(?<=monitorResolution = )\d+').Value
$renderDistance = [regex]::Match($updatedContent, '(?<=renderDistance = )\d+').Value

if ($monitorResolution -eq '4' -and $renderDistance -eq '25') {
    Write-Host "Changes were successful. monitorResolution is now $monitorResolution and renderDistance is now $renderDistance." -ForegroundColor Cyan
}
else {
    Write-Host "Changes were not successful." -ForegroundColor Red
}

Write-Host "`r`nGet back to work with your crewmates! No more excuses for not meeting the Company's profit quotas...`r`n" -ForegroundColor Green
#endregion ----
