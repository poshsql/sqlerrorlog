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
#Function to write Errorlog file Names------------------------------{{{
function Insert-objLogfiles($ServerID, $Name, $ModifiedDateTime){
  $cmdInsert = $connInsert.CreateCommand()
  $cmdInsert.CommandText =  "INSERT into [ERRORLOG].[LOGMASTER] (SERVERID, NAME, ModifiedDateTime) VALUES ('$ServerID', '$Name', '$ModifiedDateTime')"
  $cmdInsert.ExecuteNonQuery() | out-Null
}
#}}}
#Function to write Errorlog Enteries{{{
function Insert-objLogfileEnteries($Logid, $LogDate, $ProcessInfo, $text){
    $text=  $text.Replace("'","''")
    $cmdInsert = $connInsert.CreateCommand()
    $cmdInsert.CommandText =  "INSERT into [ERRORLOG].[LOGS] (LOGID, LogDate, ProcessInfo, Text) VALUES ('$logid', '$logdate', '$processinfo','$text')"
    $cmdInsert.ExecuteNonQuery() | out-Null
}
#}}}
#Function to Slice an errorlog entry------------------------------{{{
function Parse-ErrorEntry(){
	param(
      [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
      [string]$LogEntry,
      [string]$LogID
    )
	process {
            if ($LogEntry.Length -gt 35) {
            $LogObject = @{
				'ErrorDate' = $LogEntry.Substring(0,22);
				'ProcessInfo'  = $LogEntry.Substring(23,12);
				'Message'  = $LogEntry.Substring(35);
				'LogID'  = $LogID;
			}
            if (isDate($LogObject.ErrorDate)) {
                $obj = New-Object -TypeName PSObject -Property $LogObject
                $obj.PSObject.typenames.insert(0,'PoshSQL.ErrorLogEntry')
                write-output $obj | select "ErrorDate","ProcessInfo","Message","LogID"
            }
            }
	}

}
#}}}
# Truncate all tables before insert------------------------------{{{
$nowhere = exec-query "TRUNCATE TABLE [ERRORLOG].[LOGS]" -conn $connInsert
$nowhere = exec-query "TRUNCATE TABLE [ERRORLOG].[LOGMASTER]" -conn $connInsert
#}}}
#Get List of files($objLogfiles)------------------------------{{{
$objServers = exec-query "select * from errorlog.servers" -conn $connInsert
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
$objLogfiles |  foreach {Insert-objLogfiles $_.ServerID $_.LogFile $_.LastwriteTime}

#build it back to get the ID generated in the database for foreign Key
$logfiles = exec-query "select * from errorlog.LOGMASTER" -conn $connInsert
$objLogfiles = foreach ($logfile in $logfiles.Tables[0]){
                    $LogFileObject = @{
                        'Logfile'           = $Logfile.NAME;
                        'ModifiedDateTime'  = $Logfile.ModifiedDateTime;
                        'LogID'             = $LogFile.ID;
                        'ServerID'          = $LogFile.ServerID;
                    }
            $obj = New-Object -TypeName PSObject -Property $LogFileObject
            $obj.PSObject.typenames.insert(0,'PoshSQL.ErrorLogFiles')
            write-output $obj | select "LogFile","ModifiedDateTime","LogID","ServerID"
   }
#}}}
#Get the enteries($objLogEnteries)------------------------------{{{
$objLogEnteries =   foreach($objLogfile in $objLogfiles){
                        gc $objLogfile.logfile | % { Parse-ErrorEntry $_ $objlogfile.LogID}
                    }

#}}} 
$objLogEnteries |  foreach {Insert-objLogfileEnteries $_.LogID $_.Errordate $_.ProcessInfo $_.Message}
#$el = dir log\errorlog* | sort -property LastwriteTime -Descending | select -First 2 
#$el | gc| Parse-ErrorEntry 
#gci . *.* -rec | where { ! $_.PSIsContainer } #get the files only from the current directory
$connInsert.Close()
