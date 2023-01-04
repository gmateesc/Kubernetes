
#
# See
#   https://www.securitronlinux.com/bejiitaswrath/how-to-get-the-ip-address-of-your-computer-with-powershell/
#

Import-Module -UseWindowsPowerShell Test-Connection

Function Get-IpAddress {
  $temp = (Test-Connection -ComputerName (hostname) -Count 1).DisplayAddress
  return $temp
}

