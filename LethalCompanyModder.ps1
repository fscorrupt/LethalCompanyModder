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
            Write-Warning -Message "BepInEx directory already exist. Switching to upgrade mode."
            $Upgrade = $true
        }
    }

    # Backup BepInEx directory
    Write-Host "Backup Current BepInEx directory."
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
if ($Upgrade.IsPresent) {
    Write-Host "Update BepInEx plugin framework."
}
Else {
    Write-Host "Install BepInEx plugin framework."
}
$DownloadUrl = (Invoke-RestMethod -Uri "https://api.github.com/repos/BepInEx/BepInEx/releases/latest")."assets"."browser_download_url" | Select-String -Pattern ".*\/BepInEx_x64_.*.zip"
if (-not $DownloadUrl) { Write-Error -Message "BepInEx download URL not found." }
try {
    $TempPackage = Invoke-PackageDownloader -Url $DownloadUrl
    Write-Debug -Message "Copy BepInEx package to `"$GameDirectory`"."
    Copy-Item -Path "$TempPackage\*" -Destination $GameDirectory -Exclude "changelog.txt" -Recurse -Force
}
finally { if ($TempPackage) { Remove-Item -Path $TempPackage -Recurse } }

# Run Lethal Company executable to generate BepInEx configuration files
if ($Upgrade.IsPresent) {
    Write-Host "Launch Lethal Company to update BepInEx."
}
Else {
    Write-Host "Launch Lethal Company to install BepInEx."
}

Invoke-StartWaitStopProcess -Executable $GameExecutable -ProcessName "Lethal Company"

# Check if BepInEx files have been successfully generated
Write-Host "Validate BepInEx installation."
$BepInEx.ConfigFile, $BepInEx.LogFile | ForEach-Object -Process {
    if (Test-Path -Path $_) { Write-Debug -Message "BepInEx file `"$_`" found." }
    else { Write-Error -Message "BepInEx installation failed because `"$_`" not found." }
}

# Install Mods from Thunderstore
$ThunderstoreMods = $Mods | Where-Object -Property "Provider" -EQ -Value "Thunderstore"
$mod = $Mods | Where-Object -Property "Name" -EQ -Value "More_Emotes"
foreach ($mod in $ThunderstoreMods) {
    if ($Upgrade.IsPresent) {
        Write-Host ("       Update {0} mod by {1}." -f $mod.DisplayName, $mod.Namespace)
    }
    Else {
        Write-Host ("       Install {0} mod by {1}." -f $mod.DisplayName, $mod.Namespace)
    }
    $FullName = "{0}/{1}" -f $mod.Namespace, $mod.Name
    $DownloadUrl = (Invoke-RestMethod -Uri "https://thunderstore.io/api/experimental/package/$FullName/")."latest"."download_url"
    if (-not $DownloadUrl) { Write-Error -Message "$FullName mod download URL was not found." }
    try {
        $TempPackage = Invoke-PackageDownloader -Url $DownloadUrl
        switch ($mod.Type) {
            "BepInExPlugin" {
                Write-Debug -Message ("{0} {1}: Copy DLL files to `"{2}`"." -f $mod.Type, $FullName, $BepInEx.PluginsDirectory)
                Get-ChildItem -Path "$TempPackage\*" -Include "*.dll" -Recurse | Move-Item -Destination $BepInEx.PluginsDirectory
                if ($mod.Name -EQ "More_Emotes") {
                    $MoreEmotesFolder = $BepInEx.PluginsDirectory + "\MoreEmotes"
                    New-Item -ItemType Directory -Path $BepInEx.PluginsDirectory -Name MoreEmotes -Force | Out-Null
                    Get-ChildItem -Path "$TempPackage\*" -Include "*animationsbundle*" -Recurse | Move-Item -Destination $MoreEmotesFolder
                    Get-ChildItem -Path "$TempPackage\*" -Include "*animatorbundle*" -Recurse | Move-Item -Destination $MoreEmotesFolder
                }

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

if ($Upgrade.IsPresent) {
    Write-Host "Update of Lethal Company mods completed." -ForegroundColor Cyan
}
Else {
    Write-Host "Installation of Lethal Company mods completed." -ForegroundColor Cyan
}

# Edit config file
$HelmetCameraConfig = "RickArg.lethalcompany.helmetcameras.cfg"
$MoreEmotesConfig = "MoreEmotes.cfg"
$HelmetCameraConfigPath = $BepInEx.ConfigDirectory + "\" + $HelmetCameraConfig
$MoreEmotesConfigPath = $BepInEx.ConfigDirectory + "\" + $MoreEmotesConfig

Write-Host "        Now lets modify the config file: $HelmetCameraConfig"

# Read the content of the file
if (Test-Path $HelmetCameraConfigPath) {
    $HelmetCameraContent = Get-Content $HelmetCameraConfigPath -Raw
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
    $content | Out-File  $HelmetCameraConfigPath -Force
    Start-Sleep 2
    $content | Set-Content $HelmetCameraConfigPath
    $HelmetCameraContent = Get-Content $HelmetCameraConfigPath -Raw
}

# Use regular expressions to find and replace the values
$HelmetCameraContent = $HelmetCameraContent -replace '(?<=monitorResolution = )\d+', '4'
$HelmetCameraContent = $HelmetCameraContent -replace '(?<=renderDistance = )\d+', '25'

# Write the modified content back to the file
$HelmetCameraContent | Set-Content $HelmetCameraConfigPath

# Check if the changes were successful
$updatedHelmetCameraContent = Get-Content $HelmetCameraConfigPath -Raw
$monitorResolution = [regex]::Match($updatedHelmetCameraContent, '(?<=monitorResolution = )\d+').Value
$renderDistance = [regex]::Match($updatedHelmetCameraContent, '(?<=renderDistance = )\d+').Value

if ($monitorResolution -eq '4' -and $renderDistance -eq '25') {
    Write-Host "Changes were successful. monitorResolution is now $monitorResolution and renderDistance is now $renderDistance." -ForegroundColor Cyan
}
else {
    Write-Host "Changes were not successful." -ForegroundColor Red
}

# More Emotes Config Part
Write-Host "        Now lets modify the config file: $MoreEmotesConfig"

# Read the content of the file
if (Test-Path $MoreEmotesConfigPath) {
    $MoreEmotesContent = Get-Content $MoreEmotesConfigPath -Raw
}
Else {
    $Content = @"
## Settings file was created by plugin MoreEmotes-Sligili v1.2.2
## Plugin GUID: MoreEmotes

[EMOTE WHEEL]

# Setting type: String
# Default value: v
Key = m

[OTHERS]

## Prevents some emotes from performing while holding any item/scrap
# Setting type: Boolean
# Default value: true
InventoryCheck = true

[QUICK EMOTES]

# Setting type: String
# Default value: 3
Middle Finger = 3

# Setting type: String
# Default value: 6
The Griddy = 6

# Setting type: String
# Default value: 5
Shy = 5

# Setting type: String
# Default value: 4
Clap = 4

# Setting type: String
# Default value: 7
Twerk = 7

# Setting type: String
# Default value: 8
Salute = 8
"@
    $content | Out-File  $MoreEmotesConfigPath -Force
    Start-Sleep 2
    $content | Set-Content $MoreEmotesConfigPath
    $MoreEmotesContent = Get-Content $MoreEmotesConfigPath -Raw
}

# Use regular expressions to find and replace the values
$MoreEmotesContent = $MoreEmotesContent -replace '(?<=^\s*Key\s*=\s*)v', 'm'

# Write the modified content back to the file
$MoreEmotesContent | Set-Content $MoreEmotesConfigPath

# Check if the changes were successful
$updatedMoreEmotesContent = Get-Content $MoreEmotesConfigPath -Raw
$wheel = [regex]::Match($updatedMoreEmotesContent, '(?<=Key = )\w+').Value


if ($wheel -eq 'm') {
    Write-Host "Changes were successful. key is now $wheel." -ForegroundColor Cyan
}
else {
    Write-Host "Changes were not successful." -ForegroundColor Red
}

try {
    $Path = Get-ChildItem H: -Filter "BeepInEx" -ErrorAction SilentlyContinue
    if ($Path) {
        # Backup BepInEx directory
        Write-Host "        Backup Updated and copied to Google Drive..."
        $BackupUpdatedParams = @{
            Path            = $BepInEx.RootDirectory
            DestinationPath = "{0}_Backup_Updated.zip" -f $BepInEx.RootDirectory
        }
        Write-Debug -Message ("Backup existing BepInEx directory to `"{0}`"." -f $BackupUpdatedParams.DestinationPath)
        Compress-Archive @BackupUpdatedParams -Force
        Copy-Item $BackupUpdatedParams.DestinationPath "H:\BeepInEx\BepInEx.zip" -Force -ErrorAction SilentlyContinue
    }
}
catch {
    #nothing
}
<#
    # Doom Part
    Write-Host "Starting setup of DOOM..." -ForegroundColor Cyan

    # dot.Net Prerequisite
    Write-Host "Checking dot.Net prerequisite..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.ps1 -OutFile "$TemporaryDirectory\dotnet-install.ps1"
    & "$TemporaryDirectory\dotnet-install.ps1"
    $DoomDownloadUrl = "https://codeload.github.com/Cryptoc1/lc-doom/zip/refs/heads/develop"

    Write-Host "Starting setup of DOOM..." -ForegroundColor Cyan
    if (-not $DoomDownloadUrl) { Write-Error -Message "Doom download URL not found." }
    try {
        $TempPackage = Invoke-PackageDownloader -Url $DoomDownloadUrl
        Write-Host "        Copy Doom repo to `"$GameDirectory`"."
        Copy-Item -Path "$TempPackage\*" -Destination $GameDirectory -Recurse -Force
    }
    finally { if ($TempPackage) { Remove-Item -Path $TempPackage -Recurse } }

    Write-Host "        Now we have to create the .user csproj..."

    $doomcsprojFile = "LethalCompany.Doom.csproj.user"
    $doomcsprojPath = "$GameDirectory\lc-doom-develop\src\src\$doomcsprojFile "
    $ManagedPath = "$GameDirectory\Lethal Company_Data\Managed"
    $LCDOOMPath = "$GameDirectory\BepInEx\plugins\LC-DOOM"

    if (!(Test-Path $LCDOOMPath)) {
        New-Item -ItemType Directory -Path $LCDOOMPath | Out-Null
    }
    # Read the content of the file
    if (Test-Path $doomcsprojPath) {
        $fileContent = Get-Content $doomcsprojPath -Raw
    }
    Else {
        $Content = @"
    <PropertyGroup>
        <GameManagedDir>$ManagedPath</GameManagedDir>
        <PluginPublishDir>$LCDOOMPath</PluginPublishDir>
    </PropertyGroup>
    "@
        $content | Out-File  $doomcsprojPath -Force
        Start-Sleep 2
        $content | Set-Content $doomcsprojPath
        $fileContent = Get-Content $doomcsprojPath -Raw
        Write-Host "        Change .user csproj Game Data..."
    }

    # Switch to Project src
    Set-Location "$GameDirectory\lc-doom-develop"
    Write-Host "Starting to publish doom game..." -ForegroundColor Cyan
    dotnet publish -p:PublishPlugin=true

    Write-Host "Setup of DOOM completed..." -ForegroundColor Cyan
#>
Write-Host "`r`nGet back to work with your crewmates! No more excuses for not meeting the Company's profit quotas...`r`n" -ForegroundColor Green
#endregion ----
