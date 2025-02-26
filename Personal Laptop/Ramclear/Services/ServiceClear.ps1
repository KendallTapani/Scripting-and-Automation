$HardClearServicePath="C:\Scripts\Butler\Ramclear\Services\Services.csv"
$LogPath="C:\Scripts\Butler\Ramclear\Logs"

$Logfile="ServiceClear $(Get-Date -Format yyyy-MM-dd_HH-mm-ss).txt"

$ServiceList=Import-Csv -Path $HardClearServicePath -Delimiter ','

foreach($Service in $ServiceList){
    $CurrentServiceStatus=(Get-Service -Name $Service.Name).status
    if($Service.Status -ne $CurrentServiceStatus){
        Set-Service -Name $Service.Name -Status $Service.Status -Force -ErrorAction SilentlyContinue
            $log="Ended Service : $Service.Name"
            Out-File -FilePath "$LogPath\$Logfile" -Append -InputObject $log
    }
}