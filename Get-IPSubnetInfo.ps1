
<#
	.SYNOPSIS
		Returns basic IP subnet information based on supplied address and mask
	
	.DESCRIPTION
		This function will take an IP Address and subnet mask conbination as input and return basic information about the subnet including first and last usable IP addresses
	
	.PARAMETER Address
		Address in CIDR format ( xxx.xxx.xxx.xxx/yy )
	
	.EXAMPLE
                PS C:\> Get-IPSubnetInfo -Address 10.152.17.240/22

                Name       : 10.152.16.0/22
                Network    : 10.152.16.0
                Mask       : 255.255.252.0
                MaskLength : 22
                FirstIP    : 10.152.16.1
                LastIP     : 10.152.19.254
                
	
	.NOTES
		Additional information about the function.
#>
function Get-IPSubnetInfo
{
    [OutputType([psobject])]
    param
    (
        [string[]]$Address
    )

   
	
    begin
    { }
	
    process
    {
        Function ByteArrayOperation
        {
            param 
            (
                [byte[]]$array1,
                [byte[]]$array2,
                [string]$Operation
            
            )
    
            $ba3 = [System.Byte[]]::new($array1.Length) 
    
            for ($i = 0; $i -lt $ba3.Length; $i++)
            {
                if ($Operation -eq 'BAND') { $ba3[$i] = $array1[$i] -band $array2[$i] }
                if ($Operation -eq 'BXOR') { $ba3[$i] = $array1[$i] -bxor $array2[$i] }
                if ($Operation -eq 'BOR') { $ba3[$i] = $array1[$i] -bor $array2[$i] }
            }
    
            $ba3
        }
    
        foreach ($SingleAddress in $Address)
        {

            #Validate IP Address is valid
            try
            {
                $AddressIP = [ipaddress]::Parse($SingleAddress.Split('/')[0])
                $ParametersValidated = $true 
            }
            catch
            {
                '{0} is invalid IP Address' -f $SingleAddress | Write-Error
                $ParametersValidated = $false 
            }

            try
            {
                $MaskLength = [int]($SingleAddress.Split('/')[1])
                $ParametersValidated = $ParametersValidated -and $true 
            }
            catch
            {
                '{0} has invalid mask length' -f $SingleAddress | Write-Error
                $ParametersValidated = $false
            }

            if ($masklength -lt 1)
            {
                $ParametersValidated = $false
                '{0} has mask length too small' -f $SingleAddress | Write-Error
            }

            if ($AddressIP.AddressFamily -eq 'InterNetworkV6' -and $masklength -gt 126)
            {
                $ParametersValidated = $false
                '{0} has mask length too large for IPv6' -f $SingleAddress | Write-Error
            }

            if ($ParametersValidated)
            {
                $MaskBytes = [byte[]]::new($AddressIP.GetAddressBytes().Length)
            
                $i = 0
                do
                {
                    if ($maskLength -ge ((1 + $i) * 8)) 
                    { 
                        $MaskBytes[$i] = 255
                    }
                    else
                    {
                        $MaskBytes[$i] = (255 -shl ((1 + $i) * 8) - $maskLength) % 256
                    }
            
                    $i++
                } while ($maskLength -gt ($i * 8))
            
                $MaskAddress = [IPAddress]::new($MaskBytes)
			
                $NetworkAddress = [ipaddress]::new((ByteArrayOperation $AddressIP.GetAddressBytes() $MaskAddress.GetAddressBytes() -Operation BAND))
			

                if ($MaskBytes[-1] -le 252)
                {
                    $FirstIPByteArray = $NetworkAddress.GetAddressBytes()
                    $FirstIPByteArray[-1] += 1
                    $FirstIPAddress = [ipaddress]::new($FirstIPByteArray)
			
                    $BroadcastIPByteArray = [System.Byte[]]::new($FirstIPByteArray.Length)
                    for ($i = 0; $i -lt $BroadcastIPByteArray.Length; $i++) { $BroadcastIPByteArray[$i] = 255 }
			
                    $NetworkByteArray = $NetworkAddress.GetAddressBytes()
                    $MaskByteArray = $MaskAddress.GetAddressBytes()
			
                    $HostByteArray = ByteArrayOperation $MaskByteArray $BroadcastIPByteArray -Operation BXOR
                    $LastIPByteArray = ByteArrayOperation $NetworkByteArray $HostByteArray -Operation BOR
			
                    $LastIPByteArray[-1] -= 1
			
                    $LastIPAddress = [ipaddress]::new($LastIPByteArray)
                }
                else
                {
                    $FirstIPAddress = $null
                    $LastIPAddress = $null
                }

                $obj = [pscustomobject][ordered] @{
                    Address        = $AddressIP.ToString()
                    NetworkName    = $NetworkAddress.ToString() + '/' + $masklength
                    NetworkAddress = $NetworkAddress.ToString()
                    NetworkMask    = $MaskAddress.ToString()
                    MaskLength     = $masklength
                    FirstIPAddress = $FirstIPAddress
                    LastIPAddress  = $LastIPAddress
                }
			
                $obj
            }
        }
    }
	
    end
    {
		
    }
}
