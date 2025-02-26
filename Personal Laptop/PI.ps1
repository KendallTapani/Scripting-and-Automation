Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Define Pi to 50 decimal places
$Pi = "3.14159265358979323846264338327950288419716939937510"

# Function to check Pi digits (from previous script)
function Test-PiMatch {
    param (
        [string]$Input,
        [string]$FullPi
    )
    
    $Input = $Input.TrimEnd('0').TrimEnd('.')
    
    if ($Input.Length > $FullPi.Length) {
        return "Your input is longer than the target Pi value!"
    }
    
    $relevantPiPortion = $FullPi.Substring(0, [Math]::Min($Input.Length, $FullPi.Length))
    
    if ($Input -eq $relevantPiPortion) {
        $digitCount = $Input.Length
        $decimalPlaces = $digitCount - 2
        
        $response = switch ($decimalPlaces) {
            {$_ -ge 48} { "Amazing! $decimalPlaces decimal places!" }
            {$_ -ge 40} { "Impressive! $decimalPlaces decimal places!" }
            {$_ -ge 30} { "Great job! $decimalPlaces decimal places!" }
            {$_ -ge 20} { "Nice! $decimalPlaces decimal places!" }
            {$_ -ge 10} { "Good start! $decimalPlaces decimal places!" }
            default { "$decimalPlaces decimal places - keep practicing!" }
        }
        return $response
    }
    else {
        $correctDigits = 0
        for ($i = 0; $i -lt $Input.Length; $i++) {
            if ($i -ge $FullPi.Length -or $Input[$i] -ne $FullPi[$i]) {
                break
            }
            $correctDigits++
        }
        
        $decimalPlaces = [Math]::Max(0, $correctDigits - 2)
        return "Incorrect at position $correctDigits (${decimalPlaces} decimal places correct)"
    }
}

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Pi Digit Checker"
$form.Size = New-Object System.Drawing.Size(600, 400)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Create a label to display Pi
$piLabel = New-Object System.Windows.Forms.Label
$piLabel.Location = New-Object System.Drawing.Point(20, 20)
$piLabel.Size = New-Object System.Drawing.Size(560, 60)
$piLabel.Text = "π = $Pi"
$piLabel.Font = New-Object System.Drawing.Font("Consolas", 12)
$piLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$form.Controls.Add($piLabel)

# Create the start button
$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(200, 100)
$startButton.Size = New-Object System.Drawing.Size(200, 40)
$startButton.Text = "Start Challenge"
$form.Controls.Add($startButton)

# Create input field (initially hidden)
$inputBox = New-Object System.Windows.Forms.TextBox
$inputBox.Location = New-Object System.Drawing.Point(20, 160)
$inputBox.Size = New-Object System.Drawing.Size(560, 30)
$inputBox.Font = New-Object System.Drawing.Font("Consolas", 12)
$inputBox.Visible = $false
$form.Controls.Add($inputBox)

# Create input label (initially hidden)
$inputLabel = New-Object System.Windows.Forms.Label
$inputLabel.Location = New-Object System.Drawing.Point(20, 140)
$inputLabel.Size = New-Object System.Drawing.Size(200, 20)
$inputLabel.Text = "Enter digits:"
$inputLabel.Visible = $false
$form.Controls.Add($inputLabel)

# Create check button (initially hidden)
$checkButton = New-Object System.Windows.Forms.Button
$checkButton.Location = New-Object System.Drawing.Point(200, 200)
$checkButton.Size = New-Object System.Drawing.Size(200, 40)
$checkButton.Text = "Check"
$checkButton.Visible = $false
$form.Controls.Add($checkButton)

# Create result label (initially hidden)
$resultLabel = New-Object System.Windows.Forms.Label
$resultLabel.Location = New-Object System.Drawing.Point(20, 260)
$resultLabel.Size = New-Object System.Drawing.Size(560, 60)
$resultLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$resultLabel.Visible = $false
$form.Controls.Add($resultLabel)

# Add click event for the start button
$startButton.Add_Click({
    $inputBox.Visible = $true
    $inputLabel.Visible = $true
    $checkButton.Visible = $true
    $resultLabel.Visible = $true
    $startButton.Visible = $false
    $piLabel.Visible = $false
    $inputBox.Focus()
})

# Add click event for the check button
$checkButton.Add_Click({
    $result = Test-PiMatch -Input $inputBox.Text -FullPi $Pi
    $resultLabel.Text = $result
})

# Add key event for the input box (Enter key)
$inputBox.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $result = Test-PiMatch -Input $inputBox.Text -FullPi $Pi
        $resultLabel.Text = $result
    }
})

# Show the form
$form.ShowDialog()