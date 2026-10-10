$ErrorActionPreference = 'Stop'
$python = 'C:/Users/32682/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$iverilog = 'D:/Program Files/iverilog/bin/iverilog.exe'
$vvp = 'D:/Program Files/iverilog/bin/vvp.exe'
Push-Location $PSScriptRoot
try {
    & $python make_vectors.py
    if ($LASTEXITCODE) { throw 'Vector generation failed' }
    foreach ($test in @('tb_steel_ball','tb_isp_full_frame','tb_fault','tb_status_led','tb_full_recovery')) {
        $sources = @("$test.v", '../user_source/hdl_source/steel_ball_detect.v')
        if ($test -in @('tb_isp_full_frame','tb_full_recovery')) { $sources += '../user_source/hdl_source/isp/data96_128/data96_128.v' }
        & $iverilog -g2012 -I . -s $test -o "$test.vvp" @sources
        if ($LASTEXITCODE) { throw "Compile failed: $test" }
        $log = @{tb_steel_ball='simulation.log';tb_isp_full_frame='full_frame.log';tb_fault='fault.log';tb_status_led='status_led.log';tb_full_recovery='full_recovery.log'}[$test]
        & $vvp "$test.vvp" *> $log
        if ($LASTEXITCODE) { throw "Simulation failed: $test. See $log" }
        Get-Content $log | Select-Object -Last 2
    }
} finally { Pop-Location }
