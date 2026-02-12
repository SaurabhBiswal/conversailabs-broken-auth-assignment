$base_url = "http://localhost:3000"
$email = "test@example.com"
$password = "password123"
$log_file = "server.log"

# Function to read OTP from log file
function Get-OtpFromLog {
    param($sessionId)
    $max_retries = 10
    $retry_count = 0
    while ($retry_count -lt $max_retries) {
        if (Test-Path $log_file) {
            # Read file with shared access to allow server to write while we read
            $logs = Get-Content -Path $log_file -Tail 50 -ErrorAction SilentlyContinue
            foreach ($line in $logs) {
                if ($line -match "\[OTP\] Session $sessionId generated. OTP: (\d+)") {
                    return $matches[1]
                }
            }
        }
        Start-Sleep -Seconds 1
        $retry_count++
    }
    return $null
}

# 1. Login
Write-Host "1. Logging in..."
$login_body = @{
    email = $email
    password = $password
} | ConvertTo-Json

$login_response = Invoke-RestMethod -Method Post -Uri "$base_url/auth/login" -ContentType "application/json" -Body $login_body
$loginSessionId = $login_response.loginSessionId

Write-Host "Login Success. SessionId: $loginSessionId"

# Get OTP from log
Write-Host "Waiting for OTP in logs..."
$otp = Get-OtpFromLog -sessionId $loginSessionId

if (-not $otp) {
    Write-Host "Error: Could not find OTP in logs."
    exit 1
}

Write-Host "Found OTP: $otp"

# 2. Verify OTP
Write-Host "2. Verifying OTP..."
$verify_body = @{
    loginSessionId = $loginSessionId
    otp = $otp
} | ConvertTo-Json

$verify_response = Invoke-WebRequest -Method Post -Uri "$base_url/auth/verify-otp" -ContentType "application/json" -Body $verify_body -SessionVariable session

Write-Host "Verify Response: $($verify_response.Content)"

# Extract cookie value just to be sure
$cookies = $session.Cookies.GetCookies($base_url)
$session_token = $cookies["session_token"].Value
Write-Host "Session Token: $session_token"

# 3. Get Token
Write-Host "3. Getting Access Token..."
$token_response = Invoke-RestMethod -Method Post -Uri "$base_url/auth/token" -WebSession $session

$access_token = $token_response.access_token
Write-Host "Access Token: $access_token"

# 4. Access Protected Route
Write-Host "4. Accessing Protected Route..."
$headers = @{
    Authorization = "Bearer $access_token"
}
$protected_response = Invoke-RestMethod -Method Get -Uri "$base_url/protected" -Headers $headers

Write-Host "Protected Response: $($protected_response | ConvertTo-Json)"
Write-Host "SUCCESS FLAG: $($protected_response.success_flag)"
