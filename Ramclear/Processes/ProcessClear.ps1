$servicesFilePath="C:\Scripts\Butler\Ramclear\Processes\Processes.csv"
$LogPath="C:\Scripts\Butler\Ramclear\Logs"

$LogFile="ProcessClear $(Get-Date -Format yyyy-MM-dd_HH-mm-ss).txt"

$Processes=Import-CSV $servicesFilePath

foreach($process in $Processes){
        Stop-Process -Name $process.Name -Force -ErrorAction SilentlyContinue

        if($?){
        $log="Ended Process :  $($process.Name)"
        Out-File -FilePath "$LogPath\$LogFile" -Append -InputObject $log
        }
}