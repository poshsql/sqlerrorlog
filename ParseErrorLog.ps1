function isDate($object) {
  (($object -as [DateTime]) -is [DateTime])
}
function Parse-ErrorEntry(){
	param(
      [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
      [string]$LogEntry
    )
	process {
            if ($LogEntry.Length -gt 35) {
            $LogObject = @{
				'ErrorDate' = $LogEntry.Substring(0,22);
				'ProcessInfo'  = $LogEntry.Substring(23,12);
				'Message'  = $LogEntry.Substring(35);
			}
            if (isDate($LogObject.ErrorDate)) {
                $obj = New-Object -TypeName PSObject -Property $LogObject
                $obj.PSObject.typenames.insert(0,'PoshSQL.ErrorLog')
                write-output $obj | select "ErrorDate","ProcessInfo","Message"
            }
            }
	}

}
$el = dir log\errorlog* | sort -property LastwriteTime -Descending | select -First 2 
$el | gc| Parse-ErrorEntry 

#Parse-errorEntry "2013-04-26 00:00:44.20 Logon       Login failed for user 'NT AUTHORITY\SYSTEM'. Reason: Failed to open the explicitly specified database. [CLIENT: <local machine>]"
