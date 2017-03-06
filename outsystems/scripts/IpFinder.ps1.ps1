function czas {$a="$((get-date -Format yyyy-MM-dd_HH:mm:ss).ToString())"; return $a}
$log = "C:\windows\temp\IpFinder.log"
echo "$(czas) Start" >> $log

$ip = (Invoke-WebRequest 'http://myip.dnsomatic.com' -UseBasicParsing).Content
$chain = '$computerName = "' + $ip + '"'
$file = "C:\temp\OSStart.ps1"

$content = Get-Content $file ; $content | ForEach-Object { $_ -replace '^\$computerName.+$' , "$chain" } | Set-Content $file

# lifting
 # network window popup
	Stop-Service -Name lltdsvc -Force 
	Stop-Service -Name NlaSvc -Force
	Set-Service -Name lltdsvc -StartupType manual
	Set-Service -Name NlaSvc -StartupType manual
	New-Item HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff
 # network window popup stop
	
 #disable auto updates
	New-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name WindowsUpdate
	New-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name AU
	New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoUpdate -Value 1
 #disable auto updates END
 #disable IE 11 configuration popup window
	New-Item "HKLM:\Software\Policies\Microsoft\Internet Explorer"
	New-Item "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main"
	New-ItemProperty "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main\" -Name "DisableFirstRunCustomize" -Value 1 -PropertyType "DWord"
 #disable IE 11 configuration popup window END
# lifting end

echo "$(czas) MyIP: $ip" >> $log	
echo "$(czas) Stop" >> $log
exit 0