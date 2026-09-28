<#
.SYNOPSIS
  `printing` eklentisinin Windows derlemesi sırasında GitHub'dan indirdiği pdfium
  kitaplığını yerel dosyadan okumasını sağlar.

.DESCRIPTION
  CMake, TLS için Windows schannel API'sini kullanır. Kuruluş ağında sertifika
  iptal denetim noktasına (CRL/OCSP) ulaşılamıyorsa `file(DOWNLOAD)` boş dosya
  bırakır ve derleme "Build step for pdfium failed" hatasıyla durur.

  Bu betik:
    1. pdfium arşivini `curl` ile indirir (curl şema iptal denetimini atlar),
    2. eklentinin CMakeLists.txt dosyasındaki pdfium adresini yerel `file://`
       adresiyle değiştirir.

  Betik idempotenttir: arşiv zaten varsa indirmez, eklenti zaten yönlendirilmişse
  tekrar değiştirmez. Yedek dosya bir kez oluşturulur.

  Eklenti dosyası `flutter pub get` sonrası yeniden oluşturulabildiği için betiği
  `flutter pub get` / `flutter pub upgrade` sonrasında bir kez daha çalıştırmak
  gerekebilir. Betiği çalıştırmadan önce hata alıyorsanız yine de yararlıdır.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool/setup_printing_pdfium.ps1
  flutter build windows --debug
#>
[CmdletBinding()]
param(
  [string]$ProjectRoot,
  [string]$PdfiumVersion = '5200'
)

$ErrorActionPreference = 'Stop'

if (-not $ProjectRoot) {
  $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$url = "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/$PdfiumVersion/pdfium-win-x64.tgz"
$cacheDir = Join-Path $PSScriptRoot 'cache'
$archive = Join-Path $cacheDir "pdfium-win-x64-$PdfiumVersion.tgz"
$marker = 'pansiyon:yerel-pdfium'
$pluginCmake = Join-Path $ProjectRoot 'windows\flutter\ephemeral\.plugin_symlinks\printing\windows\CMakeLists.txt'

function Write-Step($message) {
  Write-Host "==> $message" -ForegroundColor Cyan
}

# 1) pdfium arşivini indir
Write-Step "pdfium $PdfiumVersion arşivi hazırlanıyor: $archive"
$needDownload = $true
if (Test-Path $archive) {
  $size = (Get-Item $archive).Length
  if ($size -gt 1MB) {
    Write-Host "    zaten indirilmiş ($([math]::Round($size / 1MB, 2)) MB), atlanıyor"
    $needDownload = $false
  } else {
    Write-Host "    mevcut dosya bozuk ($size byte), yeniden indiriliyor"
  }
}

if ($needDownload) {
  New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
  & curl.exe -L --fail --retry 3 --connect-timeout 20 -o $archive $url
  if ($LASTEXITCODE -ne 0) {
    throw "pdfium indirilemedi (curl çıkış kodu $LASTEXITCODE)."
  }
}

# 2) printing eklentisinin CMakeLists dosyasını yönlendir
if (-not (Test-Path $pluginCmake)) {
  throw "printing eklentisi bulunamadı: $pluginCmake`nÖnce 'flutter pub get' çalıştırın."
}

# Not: Burada 'file://' şeması kullanılmaz. CMake, 'file:///C:/...' adresini
# yerel dosya sanıp yolu '/C:/...' olarak çözüyor ve "File not found" hatası
# veriyor. Çıplak yerel yol ise kopyalama yöntemini tetikler ve sorunsuz çalışır.
$localSource = $archive -replace '\\', '/'

$backup = "$pluginCmake.orig"
if (-not (Test-Path $backup)) {
  Copy-Item -LiteralPath $pluginCmake -Destination $backup
  Write-Host "    yedek alındı: $backup"
}

# Her çalıştırmada yedekten temiz içerik üzerine yazar; betik idempotent kalır.
$content = Get-Content -LiteralPath $backup -Raw
$patched = [regex]::Replace(
  $content,
  'https://github\.com/bblanchon/pdfium-binaries/releases/[^"]*\.tgz',
  [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $localSource }
)

if ($patched -eq $content) {
  throw "CMakeLists.txt içinde pdfium adresi bulunamadı; eklenti sürümü değişmiş olabilir."
}

$patched = "# $marker`n$patched"
Set-Content -LiteralPath $pluginCmake -Value $patched -NoNewline
Write-Step "eklenti yerel arşive yönlendirildi: $localSource"
Write-Host "Artık 'flutter build windows --debug' çalıştırabilirsiniz."
