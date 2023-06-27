<##################################################################################################################

.Synopsis - This script is a reciever that writes a stream of data that is encoded in Base64

##################################################################################################################>

function Write-StreamToFile {
    param (
        [Parameter(Mandatory=$true)] [System.IO.Stream] $Stream,
        [Parameter(Mandatory=$true)] [string] $FilePath
    )
    $buffer = New-Object byte[] 4096
    $fileStream = New-Object System.IO.FileStream($FilePath,[System.IO.FileMode]::Create)
    while (($read = $Stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $fileStream.Write($buffer, 0, $read)
    }
    $fileStream.Close()
}

Function DecodeBase64StringFromFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, Position = 0)]
        [String]
        $FilePathContainingBase64Code,
        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $DestinationFile
    )

    If(!(Test-Path $FilePathContainingBase64Code)){
        Write-Host "File specified $FilePathContainingBase64Code not found ... please use an existing file path and try again !" -ForegroundColor Yellow -BackgroundColor Red
        $StopWatch.Stop()
        $StopWatch.Elapsed | Fl TotalSeconds
        Exit
    }

    # Below sequence transforms a file name previously converted with EncodeBase64ToFile PowerShell function into the filename extension
    # Note that the first thing we do is removing the .txt extension (4 last characters) and then the last 3 letters are the file extension
    # and the other letters are the file name withtou the extension... and finally we re-build the file name by concatenating
    # the file name without extension, with a dot, with the extension (3 last letters)
    # Example : $FilePathContainingBase64Code = "Timberexe.txt" that will become Timberexe, then Timber, then Timber.exe

    if ($DestinationFile -eq "" -or $DestinationFile -eq $null){
        Write-Verbose "-DestinationFile parameter not specified ... constructing with current Base64 file name specified: $FilePathContainingBase64Code"
        $FilePathContainingBase64Code = $FilePathContainingBase64Code.Substring(0,$FilePathContainingBase64Code.Length - 4)
        $DestinationFileExtension = $FilePathContainingBase64Code.Substring($FilePathContainingBase64Code.Length - 3)
        $DestinationFileNameWithoutExtension = $FilePathContainingBase64Code.Substring(0, $FilePathContainingBase64Code.Length - 3)
        $DestinationFile = $DestinationFileNameWithoutExtension + "." + $DestinationFileExtension
        Write-Verbose "Destination file constructed: $DestinationFile"
    } Else {
        Write-Verbose "-DestinationFile parameter specified : $DestinationFile"
    }

    Write-Verbose "Beginning TRY sequence with parameters specified -FilePathContainingBase64Code as $FilePathContainingBase64Code and -DestinationFile as $DestinationFile"
    Try {
        Write-Verbose "Trying to read the Base 64 content from file specified : $FilePathContainingBase64Code"
        $Base64Content = Get-Content -Path $FilePathContainingBase64Code
        [IO.File]::WriteAllBytes($DestinationFile, [Convert]::FromBase64String($Base64Content))
        Write-Host "Success ! File written: $DestinationFile" -BackgroundColor Green -ForegroundColor Black
    } Catch {
        Write-Verbose "Something went wrong ... We're in the CATCH section..."
        Write-Host "Something went wrong :-(" -ForegroundColor Yellow -BackgroundColor Red
    }
}


$endpoint = New-Object System.Net.IPEndPoint([ipaddress]::any,8000)
$listener = New-Object System.Net.Sockets.TcpListener $endpoint
Write-Host("0")
$listener.Start()
Write-Host("0.5")
$client = $listener.AcceptTcpClient()
Write-Host("1")
$stream = $client.GetStream()
Write-StreamToFile -stream $stream -filepath "C:\encodedServerInfo.txt"
Write-Host("1.5")
DecodeBase64StringFromFile -FilePathContainingBase64Code "C:\encodedServerInfo.txt" -DestinationFile "C:\decodedServerInfo.txt" -Verbose
$stream.Flush()
Write-Host("Gootbye")
$listener.Stop()
ii C:\decodedServerInfo.txt

##################################################################################################################

#End / Debug below

##################################################################################################################

<#
while(true){
#open stream
#if string="TEST"
        break
else
    decode
    append

wait(.01s)
}


--receiver


timer = new timer
if timer > $i*50ms
break;#>