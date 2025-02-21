$servicesFilePath="C:\Scripts\Homeauto\serviceChecker\Services.csv"
$LogPath="C:\Scripts\Homeauto\serviceChecker\Logs"
$LogFile="Services-$(Get-Date -Format "yyyy-MM-dd hh-mm").txt"
$ServicesList=Import-Csv -Path $ServicesFilePath -Delimiter ','

foreach($Service in $ServicesList){
    $CurrentServiceStatus=(Get-Service -Name $Service.Name).status

    if($Service.Status -ne $CurrentServiceStatus){
        $log="Service : $($Service.Name) is currently $CurrentServiceStatus, and should be $($Service.Status)"
        Write-Output $Log
        Out-File -FilePath "$LogPath\$Logfile" -Append -InputObject $Log

        $Log="Setting: $($Service.Name) to $($Service.Status)"
        Write-Output $Log
        Set-Service -Name $Service.Name -Status $Service.Status

        $AfterServiceStatus=(Get-Service -Name $Service.Name).Status
        if($Service.Status -eq $AfterServiceStatus){
            $Log="Action was Successful, $($Service.Name) is now $AfterServiceStatus"
            Write-Output $Log
            Out-File -FilePath "$LogPath\$Logfile" -Append -InputObject $Log
        } else{
            $Log="Action aint working, $(Service.Name) is still $AfterServiceStatus"
            Write-Output $Log
            Out-File -FilePath "$LogPath\$Logfile" -Append -InputObject $Log
        }
    }
}
