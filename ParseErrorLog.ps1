$el = dir log\errorlog* | sort -property LastwriteTime -Descending | select -First 2 
$el += dir log\errorlog* | sort -property LastwriteTime -Descending | select -First 2 
$el
