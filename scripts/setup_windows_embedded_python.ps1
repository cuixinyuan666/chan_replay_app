param(
    [Parameter(Mandatory = $true)]
    [string]$EmbeddedZip,

    [Parameter(Mandatory = $true)]
    [string]$GetPipPy,

    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ChanPySource = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Ensure-Directory([string]$Path) {
    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

$pythonDir = Join-Path $ProjectRoot "python"
$pythonExe = Join-Path $pythonDir "python.exe"
$requirements = Join-Path $pythonDir "requirements-windows.txt"
$chanPyTarget = Join-Path $pythonDir "chan.py"
$appEngine = Join-Path $pythonDir "app_engine.py"

if (!(Test-Path $EmbeddedZip)) {
    throw "EmbeddedZip not found: $EmbeddedZip"
}
if (!(Test-Path $GetPipPy)) {
    throw "GetPipPy not found: $GetPipPy"
}

Write-Step "Prepare python directory"
Ensure-Directory $pythonDir

if ((Test-Path $pythonExe) -and !$Force) {
    Write-Host "Embedded python already exists: $pythonExe"
} else {
    Write-Step "Extract Windows embeddable Python"
    Expand-Archive -Path $EmbeddedZip -DestinationPath $pythonDir -Force
}

Write-Step "Enable import site in *_pth"
$pthFiles = Get-ChildItem -Path $pythonDir -Filter "python*._pth" -File
if ($pthFiles.Count -eq 0) {
    Write-Warning "No python*._pth file found under $pythonDir"
} else {
    foreach ($pthFile in $pthFiles) {
        $pth = Get-Content $pthFile.FullName -Raw
        $pth = $pth -replace "#import site", "import site"
        if ($pth -notmatch "Lib/site-packages") {
            $pth = $pth.TrimEnd() + "`nLib/site-packages`n"
        }
        Set-Content -Path $pthFile.FullName -Value $pth -Encoding ASCII
    }
}

Write-Step "Install pip into embedded Python"
& $pythonExe $GetPipPy --no-warn-script-location

Write-Step "Install Windows runtime requirements"
if (!(Test-Path $requirements)) {
    throw "Missing $requirements. Pull latest origin_vespa_tdx first."
}
& $pythonExe -m pip install -r $requirements --no-warn-script-location

if ($ChanPySource -ne "") {
    Write-Step "Copy chan.py source"
    if (!(Test-Path $ChanPySource)) {
        throw "ChanPySource not found: $ChanPySource"
    }
    if (Test-Path $chanPyTarget) {
        Remove-Item $chanPyTarget -Recurse -Force
    }
    Copy-Item $ChanPySource $chanPyTarget -Recurse -Force
}

Write-Step "Validate required files"
if (!(Test-Path $appEngine)) {
    throw "Missing python/app_engine.py. Pull latest origin_vespa_tdx first."
}
if (!(Test-Path (Join-Path $chanPyTarget "Chan.py"))) {
    Write-Warning "python/chan.py/Chan.py not found. Windows can still use CHANPY_PATH, but packaged mode should include python/chan.py."
}

Write-Step "Smoke test"
& $pythonExe $appEngine --help | Out-Host

Write-Step "Done"
Write-Host "Windows embedded Python ready at: $pythonDir" -ForegroundColor Green
Write-Host "Flutter will prefer: $pythonExe" -ForegroundColor Green
