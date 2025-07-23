#-------------------------------------------------------
#region Utility functions
#-------------------------------------------------------
function Get-WeekNumber {
    param($date = (Get-Date))

    $Calendar = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
    $Calendar.GetWeekOfYear($date, [System.Globalization.CalendarWeekRule]::FirstFullWeek,
        [System.DayOfWeek]::Sunday)
}
#-------------------------------------------------------
function Get-IpsumLorem {
    Invoke-RestMethod https://loripsum.net/api/ul/code/headers/ol
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Lookup functions
#-------------------------------------------------------
function Get-RdpCode {
    param([int32]$code)

    $rdpcodes = Get-Content $PSScriptRoot\rdpcodes.json | ConvertFrom-Json

    $results = $rdpcodes | Where-Object Code -EQ $code
    if ($null -eq $results) {
        $results = [pscustomobject]@{
            PSTypeName  = 'RdpError'
            Error       = 'Unknown'
            Code        = [int32]$code
            Description = 'Error code was not found.'
        }
    } else {
        $results | ForEach-Object {
            $_.PSTypeNames.Insert(0,'RdpError')
        }
    }
    $results
}
#-------------------------------------------------------
function Get-ErrorCode {
    param([string]$errcode)
    [xml]$err = err.exe /:xml $errcode
    if ($err.ErrV1.err) {
        $err.ErrV1.err | Select-Object n, name, src, @{l = 'message'; e = { $_.InnerText } }
    } else {
        $err.ErrV1 | Format-List
    }
}
Set-Alias err Get-ErrorCode
#-------------------------------------------------------
function Get-User32Reason {
    param($reasoncode = 0)
    $minorcodes = @{
        0x00000000 = 'Other issue.'
        0x00000001 = 'Maintenance.'
        0x00000002 = 'Installation.'
        0x00000003 = 'Upgrade.'
        0x00000004 = 'Reconfigure.'
        0x00000005 = 'Unresponsive.'
        0x00000006 = 'Unstable.'
        0x00000007 = 'Disk.'
        0x00000008 = 'Processor.'
        0x00000009 = 'Network card.'
        0x0000000a = 'Power supply.'
        0x0000000b = 'Unplugged.'
        0x0000000c = 'Environment.'
        0x0000000d = 'Driver.'
        0x0000000e = 'Other driver event.'
        0x0000000f = 'Blue screen crash event.'
        0x00000010 = 'Service pack.'
        0x00000011 = 'Hot fix.'
        0x00000012 = 'Security patch.'
        0x00000013 = 'Security issue.'
        0x00000014 = 'Network connectivity.'
        0x00000015 = 'WMI issue.'
        0x00000016 = 'Service pack uninstallation.'
        0x00000017 = 'Hot fix uninstallation.'
        0x00000018 = 'Security patch uninstallation.'
        0x00000019 = 'MMC issue.'
        0x00000020 = 'Terminal Services.'
    }

    $majorcodes = @{
        0x00010000 = 'Hardware issue.'
        0x00020000 = 'Operating system issue.'
        0x00030000 = 'Software issue.'
        0x00040000 = 'Application issue.'
        0x00050000 = 'System failure.'
        0x00060000 = 'Power failure.'
        0x00070000 = 'Legacy API shutdown'
    }
    $flags = @{
        0x40000000 = 'The reason code is defined by the user.'
        0x80000000 = 'The shutdown was planned.'
    }
    $flag = 'Unplanned'
    $major = 'Unknown'
    $minor = 'Unknown'

    if (0x80000000 -eq ($reasoncode -band 0x80000000)) { $flag = $flags[0x80000000] }
    if (0x40000000 -eq ($reasoncode -band 0x40000000)) { $flag = '{0} {1}' -f $flag, $flags[0x40000000] }
    foreach ($x in $majorcodes.keys) {
        if (($reasoncode -band 0xf0000) -eq $x) { $major = $majorcodes[$x]; break; }
    }
    foreach ($x in $minorcodes.keys) {
        if (($reasoncode -band 0xffff) -eq $x) { $minor = $minorcodes[$x]; break; }
    }
    $result = [ordered]@{ flags = $flag; major = $major; minor = $minor }
    New-Object -type psobject -prop $result
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Event functions
#-------------------------------------------------------
function Get-LogonEvents {
    param(
        [string]$computer = $env:computername,
        [int]$days = 30
    )
    $millisecperday = 24 * 60 * 60 * 1000
    $logonType = @{
        2  = 'Interactive';
        3  = 'Network';
        4  = 'Batch';
        5  = 'Service';
        7  = 'Unlock';
        8  = 'NetworkCleartext';
        9  = 'RunAsCredentials';
        10 = 'RemoteInteractive';
        11 = 'CachedInteractive';
    }
    Get-WinEvent -LogName Security -computer $computer -FilterXPath ('*[System[(EventID=4624 or EventID=4648) and TimeCreated[timediff(@SystemTime) <= {0}]]]' -f ($days * $millisecperday)) | ForEach-Object {
        $winevent = $_
        $props = $winevent.Properties
        switch ($_.id) {
            4624 {
                $log = [ordered]@{
                    date        = $winevent.TimeCreated;
                    eventid     = $winevent.Id;
                    subjectSID  = $props[0].Value.Value;
                    subjectName = '{0}\{1}' -f $props[2].Value, $props[1].Value;
                    logonSID    = $props[4].Value.Value;
                    logonName   = '{0}\{1}' -f $props[6].Value, $props[5].Value;
                    logonType   = $logonType[[int]$props[8].Value];
                    target      = $props[11].Value;
                    process     = '[{0}] {1}' -f $props[16].Value, $props[17].Value
                }
            }
            4648 {
                $log = [ordered]@{
                    date        = $winevent.TimeCreated;
                    eventid     = $winevent.Id;
                    subjectSID  = $props[0].Value;
                    subjectName = '{0}\{1}' -f $props[2].Value, $props[1].Value;
                    logonSID    = '';
                    logonName   = $props[5].Value;
                    logonType   = 'n/a';
                    target      = $props[8].Value;
                    process     = '[{0}] {1}' -f $props[10].Value, $props[11].Value
                }
            }
        }
        New-Object -type psobject -prop $log
    }
}
#-------------------------------------------------------
function Get-RestartEvents {
    [CmdletBinding(DefaultParameterSetName = 'date')]
    param(
        [string[]]$computer = @("$env:computername"),
        [parameter(ParameterSetName = 'date')][datetime]$date = (Get-Date).AddDays(-3),
        [parameter(ParameterSetName = 'days')][int]$days = 3
    )
    switch ($PsCmdlet.ParameterSetName) {
        'date' { $starttime = $date; break }
        'days' { $starttime = (Get-Date).AddDays(-$days); break }
    }
    foreach ($c in $computer) {
        $srclist = 'EventLog', 'Microsoft-Windows-Kernel-General', 'Microsoft-Windows-Kernel-Power',
        'USER32'
        $idlist = 12, 13, 41, 109, 1001, 1074, 6005, 6006, 6008
        $props = 'LogName', 'TimeCreated', 'LevelDisplayName', 'Id', 'ProviderName', 'MachineName',
        'UserId', 'Message'
        $filterhash = @{
            Logname      = 'System'
            StartTime    = $starttime
            ProviderName = $srclist
            Id           = $idlist
        }

        Get-WinEvent -FilterHashtable $filterhash -computer $c | Select-Object $props
    }
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region System information
#-------------------------------------------------------
function Get-AssetInfo {
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$ComputerName
    )

    begin {
        if ($null -eq $ComputerName) {
            $ComputerName = $env:COMPUTERNAME
        }
    }

    process {
        foreach ($name in $ComputerName) {
            $CompSys = Get-CimInstance Win32_ComputerSystem -ComputerName $name
            $SysBios = Get-CimInstance Win32_BIOS -ComputerName $name
            $SysEncl = Get-CimInstance Win32_SystemEnclosure -ComputerName $name
            $SysDisk = Get-CimInstance Win32_DiskDrive -ComputerName $name
            $SysProc = Get-CimInstance Win32_Processor -ComputerName $name

            [pscustomobject]@{
                ComputerName = $CompSys.Name
                Manufacturer = $CompSys.Manufacturer
                Model = $CompSys.Model
                BIOSVersion = $SysBios.BIOSVersion
                AssetTag = $SysEncl.SMBIOSAssetTag
                SerialNumber = $SysBios.SerialNumber
                TotalRAM = '{0:N2} GB' -f ($CompSys.TotalPhysicalMemory / 1GB)
                DiskSize = $SysDisk.Size | %{ '{0:N2} GB' -f ($_ / 1GB)}
                Processor = ($SysProc.Name -join ', ')
            }
        }
    }
}
#-------------------------------------------------------
function Get-MUHistory {
    $objSession = New-Object -Com 'Microsoft.Update.Session'
    $objSearcher = $objSession.CreateUpdateSearcher()
    $intHistoryCount = $objSearcher.GetTotalHistoryCount()
    $colHistory = $objSearcher.QueryHistory(0, $intHistoryCount)
    $ops = @{1 = 'Install'; 2 = 'Uninstall'; }
    $rc = @{
        0 = 'Not started'
        1 = 'In progress'
        2 = 'Completed successfully'
        3 = 'Completed with errors'
        4 = 'Failed to complete'
        5 = 'Operation was aborted'
    }

    foreach ($kb in $colHistory) {
        if ($kb.Title) {
            if ($kb.Title -match 'KB\d+') {
                $id = $matches[0]
            } else {
                $id = ''
            }
            [pscustomobject]@{
                PSTypeName = 'MUHistoryType'
                KB         = $id
                Date       = '{0:yyyy-MM-dd HH:mm:ss}' -f $kb.Date
                Operation  = $ops[$kb.Operation]
                Result     = $rc[$kb.ResultCode]
                HResult    = '0x{0:X8}' -f $kb.HResult
                Title      = $kb.Title
            }
        }
    }
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Network functions
#-------------------------------------------------------
function Get-TcpStatus {
    Get-NetTCPConnection |
        Where-Object state -EQ established |
        Sort-Object LocalAddress, LocalPort |
        Select-Object LocalAddress, LocalPort, RemoteAddress,
        RemotePort, @{l = 'PID'; e = { $_.OwningProcess } },
        @{l = 'Process'; e = { (Get-Process -Id $_.owningprocess).ProcessName } } | Format-Table -AutoSize
}
Set-Alias tcpstat Get-TcpStatus
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
