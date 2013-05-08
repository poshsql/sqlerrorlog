#Set connection for Database------------------------------{{{
# gc .\DRDatapull.ps1 | ? {$_ -notlike '#*'} | clip.exe
$connInsert = New-Object System.Data.SqlClient.SqlConnection("Data Source=ps01sql01; Initial Catalog=test; Integrated Security=SSPI")
$connInsert.Open()
#}}}
#Function to Retreive data from database ------------------------------{{{
function exec-query( $sql,$parameters=@{},$conn,$timeout=30,[switch]$help){
 if ($help){
 $msg = @"
Execute a sql statement.  Parameters are allowed.
Input parameters should be a dictionary of parameter names and values.
Return value will usually be a list of datarows.
"@
 write-Log $msg
 return
 }
 $cmd=new-object system.Data.SqlClient.SqlCommand($sql,$conn)
 $cmd.CommandTimeout=$timeout
 foreach($p in $parameters.Keys){
 [Void] $cmd.Parameters.AddWithValue("@$p",$parameters[$p])
 }
 $ds=New-Object system.Data.DataSet
 $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
 $da.fill($ds) | Out-Null

 return $ds
}
#}}}
#Function to Validate a datetime------------------------------{{{
function isDate($object) {
  (($object -as [DateTime]) -is [DateTime])
}
#}}}
#Function to Slice an errorlog entry------------------------------{{{
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
                $obj.PSObject.typenames.insert(0,'PoshSQL.ErrorLogEntry')
                write-output $obj | select "ErrorDate","ProcessInfo","Message"
            }
            }
	}

}
#}}}
#Get List of Target servers ($objServers)------------------------------{{{
$objServers = exec-query "select * from errorlog.servers" -conn $connInsert
#}}}
#Get List of files($objLogfiles)------------------------------{{{
$objLogfiles = foreach ($server in $objServers.Tables[0]){
    $logfiles = gci "$($server.PATH)\errorlog*" | sort -property LastwriteTime 
    foreach ($logfile in $logfiles){
            $LogFileObject = @{
				'ServerName'    = $Server.NAME;
				'LogFile'       = $Logfile.FullName;
				'LastWriteTime' = $Logfile.LastWriteTime;
				'ServerID'      = $Server.ID;
			}
            $obj = New-Object -TypeName PSObject -Property $LogFileObject
            $obj.PSObject.typenames.insert(0,'PoshSQL.ErrorLogFiles')
            write-output $obj | select "ServerName","LogFile","LastwriteTime","ServerID"
   }
}
#}}}
$objLogfiles

#$el = dir log\errorlog* | sort -property LastwriteTime -Descending | select -First 2 
#$el | gc| Parse-ErrorEntry 
#gci . *.* -rec | where { ! $_.PSIsContainer } #get the files only from the current directory
#Parse-errorEntry "2013-04-26 00:00:44.20 Logon       Login failed for user 'NT AUTHORITY\SYSTEM'. Reason: Failed to open the explicitly specified database. [CLIENT: <local machine>]"
$connInsert.Close()
