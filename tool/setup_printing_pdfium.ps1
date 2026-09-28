<#
.SYNOPSIS
  `printing` eklentisinin Windows derlemesi sırasında GitHub'dan indirdiği pdfium
  kitaplığını yerel dosyadan okumasını sağlar; `-Restore` ile eski hâline döndürür.

.DESCRIPTION
  CMake, TLS için Windows schannel API'sini kullanır. Ağ ortamında sertifika iptal
  denetim noktasına (CRL/OCSP) ulaşılamıyorsa `file(DOWNLOAD)` boş dosya bırakır
  ve derleme "Build step for pdfium failed" hatasıyla durur:

      schannel: next InitializeSecurityContext failed: CRYPT_E_NO_REVOCATION_CHECK

  Bu bir kod hatası değil, ağ ortamı kaynaklıdır.

  Betik şunları yapar:
    1. pdfium arşivini `curl` ile indirir (curl şema iptal denetimini atlar),
    2. eklentinin özgün CMakeLists.txt dosyasını `tool/cache/` altında yedekler,
    3. eklentiyi yerel arşive yönlendirir.

  DİKKAT: `windows/flutter/ephemeral/.plugin_symlinks/printing` bir sembolik
  bağdır ve pub cache'teki gerçek dosyayı gösterir. Yani düzenleme bu makinedeki
  tüm Flutter projelerinin paylaştığı pub cache'e uygulanır. Bu yüzden betik
  özgün dosyayı `-Restore` ile geri yükleyebilir; projeyi silmeden önce mutlaka
  çalıştırın.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool/setup_printing_pdfium.ps1
  flutter build windows --debug

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool/setup_printing_pdfium.ps1 -Restore
#>
[CmdletBinding()]
param(
  [string]$ProjectRoot,
  [string]$PdfiumVersion = '5200',
  [switch]$Restore
)

$ErrorActionPreference = 'Stop'

if (-not $ProjectRoot) {
  $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$cacheDir = Join-Path $PSScriptRoot 'cache'
$archive = Join-Path $cacheDir "pdfium-win-x64-$PdfiumVersion.tgz"
$marker = 'pansiyon:yerel-pdfium'
$pristine = Join-Path $cacheDir 'printing-CMakeLists.txt.orig'

# Sembolik bağı çözerek pub cache'teki gerçek dosyayı hedefle.
$link = Join-Path $ProjectRoot 'windows\flutter\ephemeral\.plugin_symlinks\printing'
if (-not (Test-Path $link)) {
  throw "printing eklentisi bulunamadı: $link`nÖnce 'flutter pub get' çalıştırın."
}
$realDir = (Get-Item -LiteralPath $link -Force).Target
if (-not $realDir) { $realDir = $link }
$pluginCmake = Join-Path $realDir 'windows\CMakeLists.txt'
if (-not (Test-Path $pluginCmake)) {
  throw "printing eklentisinin CMakeLists.txt dosyası bulunamadı: $pluginCmake"
}

function Write-Step($message) {
  Write-Host "==> $message" -ForegroundColor Cyan
}

# -Restore: özgün dosyayı geri yükle
if ($Restore) {
  if (-not (Test-Path $pristine)) {
    throw "Yedek bulunamadı: $pristine`nEklenti zaten özgün hâlindeyse yapılacak bir şey yok."
  }
  Copy-Item -LiteralPath $pristine -Destination $pluginCmake -Force
  Write-Step "printing eklentisi özgün hâline döndürüldü"
  Write-Host "    hedef: $pluginCmake"
  return
}

$current = Get-Content -LiteralPath $pluginCmake -Raw
if ($current.Contains($marker)) {
  Write-Step "eklenti zaten yerel pdfium kaynağına yönlendirilmiş"
  return
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
  $url = "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/$PdfiumVersion/pdfium-win-x64.tgz"
  & curl.exe -L --fail --retry 3 --connect-timeout 20 -o $archive $url
  if ($LASTEXITCODE -ne 0) {
    throw "pdfium indirilemedi (curl çıkış kodu $LASTEXITCODE)."
  }
}

# 2) özgün dosyayı yedekle
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
if (-not (Test-Path $pristine)) {
  Copy-Item -LiteralPath $pluginCmake -Destination $pristine
  Write-Host "    özgün dosya yedeklendi: $pristine"
}

# Not: 'file://' şeması kullanılmaz. CMake, 'file:///C:/...' adresini yerel
# dosya sanıp yolu '/C:/...' olarak çözüyor ve "File not found" hatası veriyor.
# Çıplak yerel yol ise kopyalama yöntemini tetikler ve sorunsuz çalışır.
$localSource = $archive -replace '\\', '/'
$patched = [regex]::Replace(
  $current,
  'https://github\.com/bblanchon/pdfium-binaries/releases/[^"]*\.tgz',
  [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $localSource }
)

if ($patched -eq $current) {
  throw "CMakeLists.txt içinde pdfium adresi bulunamadı; eklenti sürümü değişmiş olabilir."
}

Set-Content -LiteralPath $pluginCmake -Value "# $marker`n$patched" -NoNewline
Write-Step "eklenti yerel arşive yönlendirildi: $localSource"
Write-Host "    hedef: $pluginCmake"
Write-Host "    geri almak için: -Restore"
Write-Host "Artık 'flutter build windows --debug' çalıştırabilirsiniz."
