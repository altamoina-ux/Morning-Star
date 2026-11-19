param(
    [ValidateSet('run', 'check', 'test', 'build', 'emulator')]
    [string]$Action = 'run',
    [string]$DeviceId = '',
    [string]$ApiBaseUrl = '',
    [string]$FlutterSdk = 'D:\development\flutter'
)
$ErrorActionPreference = 'Stop'
$flutter = Join-Path $FlutterSdk 'bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) {
    $command = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $command) { throw 'Flutter not found. Pass -FlutterSdk or read docs/tablet.md.' }
    $flutter = $command.Source
}
if (-not $env:FLUTTER_STORAGE_BASE_URL) { $env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn' }
if (-not $env:PUB_HOSTED_URL) { $env:PUB_HOSTED_URL = 'https://pub.dev' }
Push-Location (Join-Path $PSScriptRoot '..\tablet_app')
try {
    if ($Action -eq 'check') {
        & $flutter doctor -v
        & $flutter devices
    } elseif ($Action -eq 'emulator') {
        & $flutter emulators --launch QimingHatTablet
    } else {
        & $flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
        if ($Action -eq 'test') {
            & $flutter analyze
            if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }
            & $flutter test
        } elseif ($Action -eq 'build') {
            & $flutter build apk --debug
        } else {
            $runArgs = @('run')
            if ($DeviceId) { $runArgs += @('-d', $DeviceId) }
            if ($ApiBaseUrl) { $runArgs += "--dart-define=API_BASE_URL=$ApiBaseUrl" }
            & $flutter @runArgs
        }
        if ($LASTEXITCODE -ne 0) { throw "Flutter $Action failed; see output above." }
    }
} finally { Pop-Location }
