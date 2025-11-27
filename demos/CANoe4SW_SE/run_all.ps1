# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT

param (
    [string]$SILKitDir
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3

# Check if exactly one argument is passed
if (-not $SILKitDir) {
    # If no argument is passed, check if SIL Kit dir has its own environment variable (for the ci-pipeline)
    $SILKitDir = $env:SILKit_InstallDir
    if (-not $SILKitDir) {
        Write-Host "[error] SILKitDir not defined, either provide the path to the SIL Kit directory as an argument or set the `$env:SILKit_InstallDir` environment variable"
        Write-Host ("Usage:`r`n" `
          + "    .\run_all.ps1 <path_to_sil_kit_dir>")
        exit 1
    }
}

function CreateProcessObject
{
  param(
    [Parameter(Mandatory=$true)][string]$command, 
    [Parameter(Mandatory=$false)][string]$arguments, 
    [Parameter(Mandatory=$false)][string]$outputfilename
  )

  $Process = New-Object System.Diagnostics.Process
  $Process.StartInfo.FileName = $command
  $Process.StartInfo.Arguments = $arguments
  $Process.StartInfo.UseShellExecute = $false
  $Process.StartInfo.RedirectStandardOutput = $true
  $Process.StartInfo.RedirectStandardError = $true
  
  if( $outputfilename ){
    if( Test-Path $outputfilename ){
       Remove-Item $outputfilename
    }
    Add-Member                 `
      -InputObject $Process    `
      -Name "OutputFilename"   `
      -MemberType NoteProperty `
      -Value $outputfilename #([System.IO.StreamWriter]::new($outputfilename))
    
    foreach($event in @('OutputDataReceived','ErrorDataReceived'))
    { 
      Register-ObjectEvent `
        -InputObject $Process `
        -EventName $event `
        -Action {
          Add-Content -Path $Sender.OutputFilename -Value $EventArgs.Data
        } |
      Out-Null
    }
  }
  return $Process
}

function StartProcess
{
  param(
    [Parameter(Mandatory=$true)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory=$false)][string]$ProcessLegibleName
  )

  if (-not $ProcessLegibleName) {
    $ProcessLegibleName = $Process.StartInfo.FileName
  }

  try {
    Write-Output "[info] Starting $ProcessLegibleName"

    if ($Process.Start()) {
      Write-Output "[info] $ProcessLegibleName started ($($Process.Id))"
    }

    if ($Process.PSObject.Properties.Name -contains "OutputFilename") {
      # Start recording the logs
      $Process.BeginOutputReadLine()
      $Process.BeginErrorReadLine()
    }
  }
  catch {
    # Prevent silencing the classical exception output in a try/finally block.
    # Such exceptions are: "Command not found".
    # Processes' error goes in their output anyway.
    Write-Error "While starting ${ProcessLegibleName}:"
    Write-Error $_
    Write-Error $_.GetType()
    Write-Error $_.Exception
    Write-Error $_.Exception.StackTrace
    throw
  }
}

function StopProcess
{
  param(
    [Parameter(Mandatory=$true)][System.Diagnostics.Process]$Process
  )
  Try {
    if (-not $Process.HasExited) {
      Stop-Process -Id $Process.Id
      # sleep to give system some time to reflect process status
      Start-Sleep -Milliseconds 500
      if (-not $Process.HasExited) {
        Write-Output "[warn] Process $($Process.Id) did not exit after stop signal"
      } else {
        Write-Output "[info] Process $($Process.Id) stopped successfully"
      }
    } else {
      Write-Output "[info] Process $($Process.Id) was already stopped"
    }
  } Catch {
    if ($Process.HasExited) {
      Write-Output "[warn] Process $($Process.Id) was already stopped with error code $($Process.ExitCode)."
    } else {
      Write-Output "[error] Failed to stop process $($Process.Id): $($_.Exception.Message)"
    }
  } finally {
    if ($Process.PSObject.Properties.Name -contains "OutputStream") {
      $Process.OutputStream.Flush()
      $Process.OutputStream.Close()
    }
  }
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Processes to run the executables and commands in background
$RegistryProcess = CreateProcessObject `
  -command "$SILKitDir/sil-kit-registry.exe" `
  -arguments "--listen-uri 'silkit://0.0.0.0:8501'" `
  -outputfilename "${PSScriptRoot}\logs\sil-kit-registry_${timestamp}.out"

$EchoServerLittleProcess = CreateProcessObject `
  -command "${PSScriptRoot}\..\..\bin\sil-kit-demo-veipc-echo-server.exe" `
  -arguments "--endianness little_endian" `
  -outputfilename "${PSScriptRoot}\logs\sil-kit-demo-veipc-echo-server_little_endian_${timestamp}.out"

$EchoServerBigProcess = CreateProcessObject `
  -command "${PSScriptRoot}\..\..\bin\sil-kit-demo-veipc-echo-server.exe" `
  -arguments "--endianness big_endian" `
  -outputfilename "${PSScriptRoot}\logs\sil-kit-demo-veipc-echo-server_big_endian_${timestamp}.out"

$AdapterLittleProcess = CreateProcessObject `
  -command "${PSScriptRoot}\..\..\bin\sil-kit-adapter-veipc.exe" `
  -arguments "localhost:6666,toSocket,fromSocket --endianness little_endian" `
  -outputfilename "${PSScriptRoot}\logs\sil-kit-adapter-veipc_little_endian_${timestamp}.out"

$AdapterBigProcess = CreateProcessObject `
  -command "${PSScriptRoot}\..\..\bin\sil-kit-adapter-veipc.exe" `
  -arguments "localhost:6666,toSocket,fromSocket --endianness big_endian" `
  -outputfilename "${PSScriptRoot}\logs\sil-kit-adapter-veipc_big_endian_${timestamp}.out"

# Create the log directory
if (-not (Test-Path -Path "${PSScriptRoot}/logs")) {
    New-Item -ItemType Directory -Path "${PSScriptRoot}/logs" | Out-Null
}

function RunEndiannessTest {
    param(
        [Parameter(Mandatory=$true)][System.Diagnostics.Process]$EchoServer,
        [Parameter(Mandatory=$true)][System.Diagnostics.Process]$Adapter,
        [Parameter(Mandatory=$true)][string]$Endianness
    )
    
    $result = @()
    try {
        StartProcess $EchoServer "The echo server ($Endianness)"
        Start-Sleep -Milliseconds 500
        try {
            StartProcess $Adapter "The adapter ($Endianness)"
            Start-Sleep -Milliseconds 500
            Write-Output "[info] Starting run.ps1 test script ($Endianness)"
            $result = & "$PSScriptRoot\run.ps1" 2>&1 | Tee-Object -Variable capturedOutput
            $result = $capturedOutput
            Write-Output "[info] Tests finished ($Endianness)"
        } catch {
            Write-Output "[error] Test execution failed for ${Endianness}: $_"
            $result = @("[error] Test execution failed: $_")
        } finally {
            Write-Output "[info] Stopping adapter ($Endianness)"
            StopProcess $Adapter
        }
    } catch {
        Write-Output "[error] Failed to start processes for ${Endianness}: $_"
        $result = @("[error] Failed to start processes: $_")
    } finally {
        Write-Output "[info] Stopping echo server ($Endianness)"
        StopProcess $EchoServer
    }
    
    return $result
}

try {
    StartProcess $RegistryProcess "The SIL Kit registry"
    Start-Sleep -Seconds 2
    
    # Run little endian tests
    $scriptLittleResult = @()
    RunEndiannessTest -EchoServer $EchoServerLittleProcess -Adapter $AdapterLittleProcess -Endianness "little_endian" | 
        ForEach-Object { 
            Write-Host $_
            $scriptLittleResult += $_
        }
    
    # Run big endian tests
    $scriptBigResult = @()
    RunEndiannessTest -EchoServer $EchoServerBigProcess -Adapter $AdapterBigProcess -Endianness "big_endian" | 
        ForEach-Object { 
            Write-Host $_
            $scriptBigResult += $_
        }
} finally {
    Write-Output "[info] Stopping SIL Kit registry"
    StopProcess $RegistryProcess
}

# Save both results to log files
if ($scriptLittleResult) {
    Set-Content -Path "${PSScriptRoot}\logs\run_little_endian.ps1.out" -Value $scriptLittleResult
}
if ($scriptBigResult) {
    Set-Content -Path "${PSScriptRoot}\logs\run_big_endian.ps1.out" -Value $scriptBigResult
}

# Check if both tests passed
Write-Output "[info] Evaluating test results..."
$littlePassed = $false
$bigPassed = $false

if ($scriptLittleResult) {
    $lastLittleLine = $scriptLittleResult | Select-Object -Last 1
    $littlePassed = $lastLittleLine -match "passed"
    Write-Output "[info] Little endian test: $(if ($littlePassed) { 'PASSED' } else { 'FAILED' })"
}

if ($scriptBigResult) {
    $lastBigLine = $scriptBigResult | Select-Object -Last 1
    $bigPassed = $lastBigLine -match "passed"
    Write-Output "[info] Big endian test: $(if ($bigPassed) { 'PASSED' } else { 'FAILED' })"
}

if ($littlePassed -and $bigPassed) {
    Write-Output "[info] All tests passed (both little_endian and big_endian)"
    exit 0
}
elseif ($littlePassed) {
    Write-Output "[error] Tests failed: big_endian tests failed, little_endian tests passed"
    exit 1
}
elseif ($bigPassed) {
    Write-Output "[error] Tests failed: little_endian tests failed, big_endian tests passed"
    exit 1
}
else {
    Write-Output "[error] All tests failed (both little_endian and big_endian)"
    exit 1
}

