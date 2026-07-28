param(
    [string]$Password = '2706',
    [string]$Source = 'letter-source.txt',
    [string]$Output = 'encrypted-letter.json'
)

$plain = [System.IO.File]::ReadAllText((Resolve-Path $Source), [System.Text.Encoding]::UTF8)
$passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($Password)
$dataBytes = [System.Text.Encoding]::UTF8.GetBytes($plain)

$out = New-Object byte[] $dataBytes.Length
for ($i = 0; $i -lt $dataBytes.Length; $i++) {
    $passwordByte = $passwordBytes[$i % $passwordBytes.Length]
    $key = ($passwordByte + $i + ($i % 7)) % 256
    $out[$i] = $dataBytes[$i] -bxor $key
}

$hex = -join ($out | ForEach-Object { '{0:X2}' -f $_ })
$sha = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Password))
$hash = -join ($hashBytes | ForEach-Object { '{0:X2}' -f $_ })

$obj = [ordered]@{
    passwordHash = $hash.ToLowerInvariant()
    ciphertext = $hex
}

$obj | ConvertTo-Json -Compress | Set-Content -Path $Output -Encoding utf8
Write-Output "Updated $Output using password $Password"
