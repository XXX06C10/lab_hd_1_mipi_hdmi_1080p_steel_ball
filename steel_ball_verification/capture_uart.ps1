param(
    [string]$Port,
    [int]$Seconds = 30,
    [string]$OutputPath = (Join-Path $PSScriptRoot ("uart_capture_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss')))
)
$available = [System.IO.Ports.SerialPort]::GetPortNames()
if (-not $Port) {
    Write-Host ('Available ports: ' + (($available | Sort-Object) -join ', '))
    throw 'Specify -Port COMx after connecting the board USB-UART port.'
}
$serial = [System.IO.Ports.SerialPort]::new($Port, 115200, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
$serial.ReadTimeout = 1000
$serial.NewLine = "`n"
$deadline = (Get-Date).AddSeconds($Seconds)
$lastDetectFrames = $null
try {
    $serial.Open()
    Write-Host "Capturing $Port at 115200 8N1 to $OutputPath"
    while ((Get-Date) -lt $deadline) {
        try {
            $line = $serial.ReadLine().Trim()
            if ($line -match '^F=[0-9A-F]{4} R=[0-9A-F]{6} A=[0-9A-F]{6} P=[0-9A-F]{6} X=[0-9A-F]{3}-[0-9A-F]{3} Y=[0-9A-F]{3}-[0-9A-F]{3} G=[0-9A-F] N=[0-9A-F]{3} Q=[0-9A-F]{5} S=[0-9A-F]{2} E=[0-9A-F] V=[0-9A-F]{6} T=[0-9A-F]{3} D=[0-9A-F]{4} L=[0-9A-F]{3} B=[0-9A-F]{3}-[0-9A-F]{3} C=[0-9A-F]{2} F=[0-9A-F]{2}$') {
                $entry = '{0} {1}' -f (Get-Date -Format 'o'), $line
                Add-Content -LiteralPath $OutputPath -Value $entry
                $fields = @{}
                foreach ($item in $line.Split(' ')) {
                    $pair = $item.Split('=')
                    $fields[$pair[0]] = $pair[1]
                }
                $red = [Convert]::ToInt32($fields['R'], 16)
                $area = [Convert]::ToInt32($fields['A'], 16)
                $geom = [Convert]::ToInt32($fields['G'], 16)
                $status = [Convert]::ToInt32($fields['S'], 16)
                $errorCode = [Convert]::ToInt32($fields['E'], 16)
                $fifoPeak = [Convert]::ToInt32($fields['Q'], 16)
                $inputWords = [Convert]::ToInt32($fields['V'], 16)
                $inputLines = [Convert]::ToInt32($fields['T'], 16)
                $detectFrames = [Convert]::ToInt32($fields['D'], 16)
                $detectLines = [Convert]::ToInt32($fields['L'], 16)
                $valid = [Convert]::ToInt32($fields['C'], 16)
                $confidence = [Convert]::ToInt32($fields['F'], 16)
                $ball = $fields['B'].Split('-')
                $candidate = ($valid -band 1) -ne 0
                $confirmed = ($valid -band 2) -ne 0
                if ($status -band 0x80) { $reason = 'No ISP frame start in the last second' }
                elseif ($status -band 0x40) { $reason = 'FIFO fault active' }
                elseif ($status -band 0x20) { $reason = 'Component labels exhausted' }
                elseif ($inputWords -ne 388800 -or $inputLines -ne 1080) { $reason = 'ISP output shape differs from 1920x1080' }
                elseif ($lastDetectFrames -ne $null -and $detectFrames -eq $lastDetectFrames) { $reason = 'Detector completion count is not advancing' }
                elseif (($status -band 0x10) -or $detectLines -ne 1080) { $reason = 'Detector frame dimensions invalid' }
                elseif (-not $candidate) { $reason = 'No candidate red region' }
                elseif (-not $confirmed) {
                    $checks = @()
                    if (-not ($geom -band 1)) { $checks += 'area' }
                    if (-not ($geom -band 2)) { $checks += 'dominance' }
                    if (-not ($geom -band 4)) { $checks += 'aspect' }
                    if (-not ($geom -band 8)) { $checks += 'compact' }
                    $reason = 'Candidate not confirmed: ' + ($checks -join ', ')
                }
                else { $reason = 'Ball confirmed; center is valid for control' }
                Write-Host ("$entry | red=$red area=$area center=($($ball[0]),$($ball[1])) cand=$candidate conf=$confirmed conf_lvl=$confidence geom=$geom input_frames=$detectFrames lines=$detectLines | $reason")
                $lastDetectFrames = $detectFrames
            }
        } catch [System.TimeoutException] {
        }
    }
} finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
Write-Host "Saved: $OutputPath"
