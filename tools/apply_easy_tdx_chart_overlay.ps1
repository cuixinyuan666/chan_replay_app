$ErrorActionPreference = 'Stop'

$path = 'lib/ui/pages/origin_replay_page_v2.dart'
if (!(Test-Path $path)) {
  throw "File not found: $path"
}

$content = Get-Content $path -Raw -Encoding UTF8
$old = "import '../widgets/origin_kline_chart.dart';"
$new = "import '../widgets/easy_tdx_origin_kline_chart.dart';"

if ($content.Contains($new)) {
  Write-Host 'easy-tdx chart overlay import already installed.'
  exit 0
}

if (!$content.Contains($old)) {
  throw "Expected import not found: $old"
}

$content = $content.Replace($old, $new)
Set-Content $path $content -Encoding UTF8
Write-Host 'Installed easy-tdx chart overlay import.'
Write-Host 'Run: flutter analyze'
