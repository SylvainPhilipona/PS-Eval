Function Create-AutoEvals {
param (
    [string]$ConfigsPath, # = "$($PSScriptRoot)\DataFiles\01-configs-auto-eval.xlsx",
    [string]$ModelPath, # = "$($PSScriptRoot)\DataFiles\02-modele-auto-eval.xlsx"
    [string]$OutputPath
)

# if(!(Test-Path -Path $OutputPath -PathType Container)){
#     Stop-Program -errorMessage "Le dossier $OutputPath n'existe pas"
# }

Start-Transcript -Path "./Output/Output.log" -Append -Force

#Install all requirements for the script to run
Install-Requirements

#Load the data file
$data = Import-LocalizedData -BaseDirectory ./DataFiles -FileName Inputs.psd1
Write-Host "Loading inputs file" -ForegroundColor Green

#Verify if the config and model files exists
$testPaths = Test-Paths -paths $ConfigsPath, $ModelPath
if(!$testPaths.count -eq 0){
    #Dispaly the missing paths
    $errorMessage = "Les fichiers suivants n'existent pas : `n`r"
    foreach($path in $testPaths){
        $errorMessage += " $path `n`r"
    }
    Stop-Program -errorMessage $errorMessage
}

#Import the configs and students inputs
$Configs = (Import-Excel -Path $ConfigsPath -WorksheetName $data.ConfigFile.ConfigSheet)
$Students = (Import-Excel -Path $ConfigsPath -WorksheetName $data.ConfigFile.StudentsSheet)
Write-Host "Loading configs file" -ForegroundColor Green

# Check that the Config file contains all the required inputs.
# The inputs are specified in the Inputs.psd1 file
foreach($input in $data.RequiredInputs.GetEnumerator()){
    if(!($Configs.Champs.contains($input.Value))){
        Stop-Program -errorMessage "Il manque un champ wesh"
    }
}

#Convert Configs to ConfigsHash table
$ConfigsHash = @{}
foreach($config in $Configs){
    $ConfigsHash.Add($config.Champs, $config.Valeurs)
}

foreach($student in  $students){

    Write-Host "Creating $($student.Prenom) $($student.Nom) AutoEval"

    #Import the model file
    try{
        $excel = New-Object -ComObject excel.application
    }
    catch [System.Runtime.InteropServices.COMException] {
        Stop-Program -errorMessage "Excel n'est pas installé. Veuillez l'installer et recomencer !"
    }
    $excel = New-Object -ComObject excel.application
    $excel.visible = $false
    $workbook = $excel.Workbooks.Open($ModelPath)
    $Sheet1 = $workbook.worksheets.item(1)

    #Unprotect the sheet
    $Sheet1.Unprotect()
    
    #Replace the cells with the configs datas
    $Sheet1.cells.find("[NAME]") = "$($student.Prenom) $($student.Nom)"
    $Sheet1.cells.find("[CLASSE]") = $ConfigsHash[$data.RequiredInputs.CLASSE]
    $Sheet1.cells.find("[TEACHER]") = $ConfigsHash[$data.RequiredInputs.TEACHER]
    $Sheet1.cells.find("[PROJECTNAME]") = $ConfigsHash[$data.RequiredInputs.PROJECTNAME]
    $Sheet1.cells.find("[NBWEEKS]") = $ConfigsHash[$data.RequiredInputs.NBWEEKS]
    $Sheet1.cells.find("[DATES]") = "$($ConfigsHash[$data.RequiredInputs.DATES].ToString("yyyy/MM/dd"))-$($ConfigsHash["Date fin"].ToString("yyyy/MM/dd"))"

    #Set the sheet name
    $Sheet1.Name = "$($student.Prenom) $($student.Nom)"

    #Protect the sheet
    $Sheet1.Protect()
    
    #Save the new file as the student name (Overwrite if the file exists)
    $filename = "$($PSScriptRoot)\Output\AutoEval-$($student.Prenom + "-" + $student.Nom).xlsx"
    Remove-Item -Path $filename -Force -Confirm:$false -ErrorAction SilentlyContinue
    $workbook.Saveas($filename)
    Write-Host "    --> Saving $filename"

    
    #Close the object
    $excel.workbooks.Close()
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
}

Stop-Transcript
}
Function Get-AutoEvals {
param (
    [string]$ConfigsPath, # = "$($PSScriptRoot)\DataFiles\01-configs-auto-eval.xlsx",
    [string]$SynthesisModelPath, # = "$($PSScriptRoot)\DataFiles\03-synthese-auto-eval.xlsm",
    [string]$FilesPath # = "$($PSScriptRoot)\Output"
)

if(!(Test-Path -Path $FilesPath -PathType Container)){
    Stop-Program -errorMessage "Le dossier $FilesPath n'existe pas"
}

Start-Transcript -Path "$FilesPath/Output.log" -Append -Force

#Install all requirements for the script to run
Install-Requirements

#Load the data file
$data = Import-LocalizedData -BaseDirectory ./DataFiles -FileName Inputs.psd1
Write-Host "Loading inputs file" -ForegroundColor Green

#Import the configs and students inputs
$Configs = (Import-Excel -Path $ConfigsPath -WorksheetName $data.ConfigFile.ConfigSheet)
Write-Host "Loading configs file" -ForegroundColor Green

# Verify that the folder exists
if(!(Test-Path $FilesPath -PathType Container)){
    Stop-Program -errorMessage "Le dossier '$FilesPath' n'existe pas"
}

#Get all excel files in the path
$AutoEvals = Get-ChildItem -Path $FilesPath -recurse -File -Include *.xlsx

# Verify that the path contains at least 1 AutoEval
if($AutoEvals.Length -lt 1){
    Stop-Program -errorMessage "Le dossier '$FilesPath' ne contient pas d'auto évaluations"
}

#Create the com object
try{
    $excel = New-Object -ComObject excel.application
    $excel.visible = $false
}
catch [System.Runtime.InteropServices.COMException] {
    Stop-Program -errorMessage "Excel n'est pas installé. Veuillez l'installer et recomencer !"
}

$WorkbooxSynthesis = $excel.workbooks.Open($SynthesisModelPath)

# Recover all evals in the folder
foreach($eval in $AutoEvals){

    Write-Host "Importing $($eval.FullName)"

    #Open the auto eval
    $WorkbookEval = $excel.Workbooks.Open($eval.FullName)
    $SheetEval = $WorkbookEval.worksheets.item(1)

    #Copy the auto eval in the synthesis file
    $SheetEval.copy($WorkbooxSynthesis.sheets.item(1))
    $WorkbookEval.Close()
}

#Convert Configs to ConfigsHash table
$ConfigsHash = @{}
foreach($config in $Configs){
    $ConfigsHash.Add($config.Champs, $config.Valeurs)
}


#Save and close the object
# AutoEvals-ProjectName-Classe-Prof-01.xlsm
$ExcelFixedFormat = [Microsoft.Office.Interop.Excel.XlFileFormat]::xlOpenXMLWorkbookMacroEnabled
$FileName = "$FilesPath\AutoEvals-$($ConfigsHash[$data.RequiredInputs.PROJECTNAME])-$($ConfigsHash[$data.RequiredInputs.CLASSE])-$($ConfigsHash[$data.RequiredInputs.VISA])-1.xlsm"
$WorkbooxSynthesis.Saveas($FileName,$ExcelFixedFormat)
$excel.workbooks.Close()
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
"Saving $filename"

Stop-Transcript
}
Function Install-Requirements {
#Install the NuGet package
Write-Host "Installing NuGet" -ForegroundColor Green
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Scope CurrentUser -Force -Confirm:$false | Out-Null

if((Get-PSRepository -Name "PSGallery").InstallationPolicy -ne "Trusted"){
    Write-Host "Setting PSGallery repo to Trusted" -ForegroundColor Green
    Set-PSRepository -name  "PSGallery" -InstallationPolicy Trusted
}

if(!(Get-Module -ListAvailable -name ImportExcel)){
    Write-Host "Instaling ImportExcel" -ForegroundColor Green
    Install-Module ImportExcel -Scope CurrentUser -Confirm:$false #https://github.com/dfinke/ImportExcel
}
}
Function Stop-Program {
param (
    [string]$errorMessage
)


try{
    Stop-Transcript | out-null
}
catch{}

throw $errorMessage
}
Function Test-Paths {
param (
    [String[]]$paths
)

$notExistingPaths = @()

foreach($path in $paths){
    if(!(Test-path $path)){
        $notExistingPaths += $path
    }
}

return $notExistingPaths
}
# .Net methods for hiding/showing the console in the background
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

function Hide-Console
{
    $consolePtr = [Console.Window]::GetConsoleWindow()
    #0 = hide
    [Console.Window]::ShowWindow($consolePtr, 0) | Out-Null
} 
Hide-Console

#####################  POPUP  #####################

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Main form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Récupération des AutoEvaluations'
$form.Size = New-Object System.Drawing.Size(300,300)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Topmost = $false

# Create auto-evals button
$createEvalsButton = New-Object System.Windows.Forms.Button
$createEvalsButton.Size = New-Object System.Drawing.Size(($form.Size.Width - 50),30)
$createEvalsButton.Left = ($form.ClientSize.Width - $createEvalsButton.Width) / 2 ;
$createEvalsButton.Top = 15 
$createEvalsButton.Text = 'Créer les auto-évaluations'
$form.Controls.Add($createEvalsButton)

# Get auto-evals button
$getEvalsButton = New-Object System.Windows.Forms.Button
$getEvalsButton.Size = New-Object System.Drawing.Size(($form.Size.Width - 50),30)
$getEvalsButton.Left = ($form.ClientSize.Width - $getEvalsButton.Width) / 2 ;
$getEvalsButton.Top = $createEvalsButton.Bottom + 15 
$getEvalsButton.Text = 'Rappatrier les auto-évaluations'
$form.Controls.Add($getEvalsButton)

# Config path

$configPathInput = New-Object System.Windows.Forms.TextBox
$configPathInput.Size = New-Object System.Drawing.Size(($form.Size.Width - 50),30)
$configPathInput.Left = ($form.ClientSize.Width - $configPathInput.Width) / 2 ;
$configPathInput.Top = $getEvalsButton.Bottom + 15 
$configPathInput.Text = "$($PSScriptRoot)\DataFiles\01-configs-auto-eval.xlsx"
$form.Controls.Add($configPathInput)

# Model Path
$modelPathInput = New-Object System.Windows.Forms.TextBox
$modelPathInput.Size = New-Object System.Drawing.Size(($form.Size.Width - 50),30)
$modelPathInput.Left = ($form.ClientSize.Width - $modelPathInput.Width) / 2 ;
$modelPathInput.Top = $configPathInput.Bottom + 15 
$modelPathInput.Text = "$($PSScriptRoot)\DataFiles\02-modele-auto-eval.xlsx"
$form.Controls.Add($modelPathInput)

# Synthesis Path
$synthesisPathInput = New-Object System.Windows.Forms.TextBox
$synthesisPathInput.Size = New-Object System.Drawing.Size(($form.Size.Width - 50),30)
$synthesisPathInput.Left = ($form.ClientSize.Width - $synthesisPathInput.Width) / 2 ;
$synthesisPathInput.Top = $modelPathInput.Bottom + 15 
$synthesisPathInput.Text = "$($PSScriptRoot)\DataFiles\03-synthese-auto-eval.xlsm",
$form.Controls.Add($synthesisPathInput)

# Output Path
$outputPathInput = New-Object System.Windows.Forms.TextBox
$outputPathInput.Size = New-Object System.Drawing.Size(($form.Size.Width - 50),30)
$outputPathInput.Left = ($form.ClientSize.Width - $outputPathInput.Width) / 2 ;
$outputPathInput.Top = $synthesisPathInput.Bottom + 15 
$outputPathInput.Text = "$($PSScriptRoot)\Output",
$form.Controls.Add($outputPathInput)


# Create auto-evals Button event
$createEvalsButton.Add_Click(
    {    
        # Lock the form and buttons
        $form.Enabled = $false

        # Trim the Output Path 
        $outputPathInput.Text = $outputPathInput.Text.TrimEnd(' ')
        $outputPathInput.Text = $outputPathInput.Text.TrimEnd('\')

        try{
            # Start the creation
            Create-AutoEvals -ConfigsPath $configPathInput.Text -ModelPath $modelPathInput.Text -OutputPath $outputPathInput.Text

            [System.Windows.Forms.MessageBox]::Show("Tout bon" , "My Dialog Box")
        }
        catch{
            #Display the error message
            [System.Windows.Forms.MessageBox]::Show($_ , "Erreur d'execution")
        }
        
        # Unlock the form and buttons
        $form.Enabled = $true
    }
);

# Get auto-evals Button event
$getEvalsButton.Add_Click(
    {    
        # Lock the form and buttons
        $form.Enabled = $false

        # Trim the Output Path 
        $outputPathInput.Text = $outputPathInput.Text.TrimEnd(' ')
        $outputPathInput.Text = $outputPathInput.Text.TrimEnd('\')

        try{
            # Start the creation
            Get-AutoEvals -ConfigsPath $configPathInput.Text -SynthesisModelPath $synthesisPathInput.Text -FilesPath $outputPathInput.Text

            [System.Windows.Forms.MessageBox]::Show("Tout bon" , "My Dialog Box")
        }
        catch{
            #Display the error message
            [System.Windows.Forms.MessageBox]::Show($_ , "Erreur d'execution")
        }
        
        # Unlock the form and buttons
        $form.Enabled = $true
    }
);


$result = $form.ShowDialog()
$result
