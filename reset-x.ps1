#requires -Version 5.1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$archiveUrl = 'https://git.cu3rd.ru/cu3rd/aircul-cuya/archive/master.zip'
$tempPath = Join-Path ([IO.Path]::GetTempPath()) ('reset-station-' + [Guid]::NewGuid().ToString('N'))

try {
    $location = Get-Location
    if ($location.Provider.Name -ne 'FileSystem') {
        throw 'Откройте обычную папку X в VS Code и создайте новый терминал. Ничего не удалено.'
    }

    $target = $location.ProviderPath
    if ([IO.Path]::GetFileName($target.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) -ne 'X') {
        $message = @(
            'Терминал открыт не в папке X.'
            "Текущая папка: $target"
            ''
            'Что сделать:'
            '1. Откройте папку X в VS Code и создайте новый терминал.'
            '2. Либо перейдите в неё командой: cd "полный\путь\к\X"'
            '3. Повторите команду сброса.'
            ''
            'Ничего не удалено.'
        ) -join "`n"
        throw $message
    }

    $root = [IO.Path]::GetPathRoot($target)
    if ($target.TrimEnd('\', '/') -eq $root.TrimEnd('\', '/')) {
        throw 'Очистка корня диска запрещена.'
    }

    $archive = Join-Path $tempPath 'tasks.zip'
    $extracted = Join-Path $tempPath 'extracted'
    New-Item -ItemType Directory -Path $extracted -Force | Out-Null

    Write-Host '[1/3] Скачивание и проверка свежих задач...' -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $archiveUrl -OutFile $archive -UseBasicParsing -TimeoutSec 60
    Expand-Archive -LiteralPath $archive -DestinationPath $extracted -Force

    $sourceDirectories = @(Get-ChildItem -LiteralPath $extracted -Directory -Force)
    if ($sourceDirectories.Count -ne 1) {
        throw 'Не удалось определить корневую папку в скачанном архиве.'
    }

    $source = $sourceDirectories[0].FullName
    if (@(Get-ChildItem -LiteralPath $source -Force).Count -eq 0) {
        throw 'Скачанный архив пуст. Текущие задачи не изменены.'
    }

    Write-Host '[2/3] Очистка содержимого папки X...' -ForegroundColor Cyan
    Get-ChildItem -LiteralPath $target -Force | Remove-Item -Recurse -Force -ErrorAction Stop

    Write-Host '[3/3] Распаковка новых задач...' -ForegroundColor Cyan
    Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $target -Recurse -Force -ErrorAction Stop

    Write-Host ''
    Write-Host 'Готово! Папка X содержит свежие задачи.' -ForegroundColor Green
    Write-Host 'VS Code перезапускать не нужно.'
}
catch {
    Write-Host ''
    Write-Host ('ОШИБКА: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Исправьте указанную причину и повторите команду. VS Code закрывать не нужно.'
    exit 1
}
finally {
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
