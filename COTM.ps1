
### Cmdlet of the Month ###

Get-Date

[datetime]::Today

Get-date | gm

(get-date -Year 2015 -Month 11 -Day 5).DayOfWeek

(get-date).IsDaylightSavingTime()

Get-date -Format yyyy

(get-date -Format o).Replace(":",".")

<#
-- FileDate - A file or path-friendly representation of the current date in local time. 
    It is in the form of yyyymmdd ( using 4 digits, 2 digits, and 2 digits). An example of results when you use this format is 20150302.
-- FileDateUniversal - A file or path-friendly representation of the current date in universal time. 
    It is in the form of yyyymmdd + 'Z' (using 4 digits, 2 digits, and 2 digits). An example of results when you use this format is 20150302Z.
-- FileDateTime - A file or path-friendly representation of the current date and time in local time, in 24-hour format. 
    It is in the form of yyyymmdd + 'T' + hhmmssmsms, where msms is a four-character representation of milliseconds. An example of results when you use this format is 20150302T1240514987.
-- FileDateTimeUniversal - A file or path-friendly representation of the current date and time in universal time, in 24-hour format. 
    It is in the form of yyyymmdd + 'T' + hhmmssmsms, where msms is a four-character representation of milliseconds, + 'Z'. An example of results when you use this format is 20150302T0840539947Z.
#>


Get-Date -UFormat "%Y / %m / %d / %A / %Z"

C:\PSUG\Nov17\Test-DatePattern.ps1

#Methods

(get-date).IsDaylightSavingTime()

(get-date).ToUniversalTime()

$time = New-TimeSpan -Days 5
(get-date).Subtract($time)


#This is not a date time object
"11/12/2015"

$a = [datetime]"11/12/2015"



