[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('edgeapp', 'app-only', 'docker-host')]
  [string]$Profile,

  [Parameter(Mandatory = $true)]
  [int]$VmId,

  [Parameter(Mandatory = $true)]
  [string]$Name,

  [Parameter(Mandatory = $true)]
  [int]$TemplateId,

  [int]$Cores = 4,
  [int]$MemoryMb = 8192,
  [string]$Bridge = 'vmbr0',
  [string]$Storage = 'local-zfs',
  [string]$SnippetsStorageId = 'synology.lan',
  [string]$SnippetsPath = '/mnt/pve/synology.lan/snippets',
  [string]$Ref = 'main',
  [string]$RepoUrl = 'https://github.com/SamuelMcAravey/infra-bootstrap',

  [string]$AppImage,
  [string]$ZeroTierNetworkId,
  [SecureString]$CloudflareTunnelToken,
  [string]$ComposeProjectDir = '/srv/app',
  [string]$EdgeNetworkName = 'edge'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message"
}

function Write-Warn {
  param([string]$Message)
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Die {
  param([string]$Message)
  Write-Host "[ERROR] $Message" -ForegroundColor Red
  exit 2
}

function Get-RawBaseFromRepoUrl {
  param([string]$Repo)

  $normalized = $Repo.TrimEnd('/')
  if ($normalized.EndsWith('.git')) {
    $normalized = $normalized.Substring(0, $normalized.Length - 4)
  }

  if ($normalized -match '^https://github\.com/') {
    return ($normalized -replace '^https://github\.com/', 'https://raw.githubusercontent.com/')
  }

  return 'https://raw.githubusercontent.com/SamuelMcAravey/infra-bootstrap'
}

function Get-RemoteText {
  param([string]$Url)

  try {
    Write-Info "Downloading: $Url"
    $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
    return $resp.Content
  } catch {
    $curl = Get-Command curl -ErrorAction SilentlyContinue
    if (-not $curl) {
      throw
    }
    Write-Info "Invoke-WebRequest failed, retrying with curl."
    $content = & curl -fsSL $Url
    if ($LASTEXITCODE -ne 0) {
      throw "curl failed to download: $Url"
    }
    return $content
  }
}

function Get-PlainText {
  param([SecureString]$Secure)

  if (-not $Secure) {
    return ''
  }

  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Render-Template {
  param(
    [string]$Template,
    [hashtable]$Values
  )

  $output = $Template
  foreach ($key in $Values.Keys) {
    $placeholder = "{{${key}}}"
    $value = $Values[$key]
    if ($null -eq $value) {
      $value = ''
    }
    $pattern = [Regex]::Escape($placeholder)
    $output = [Regex]::Replace($output, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ $value })
  }
  return $output
}

function Ensure-SnippetsPath {
  param([string]$Path)
  if (-not (Test-Path -Path $Path)) {
    Write-Info "Creating snippets path: $Path"
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Invoke-Qm {
  param([string[]]$Args)
  Write-Info ("qm " + ($Args -join ' '))
  & qm @Args
  if ($LASTEXITCODE -ne 0) {
    Die "qm failed: qm $($Args -join ' ')"
  }
}

if (-not (Get-Command qm -ErrorAction SilentlyContinue)) {
  Die "qm is not available on PATH. Run this on a Proxmox host."
}

if (-not (Get-Command pvesm -ErrorAction SilentlyContinue)) {
  Die "pvesm is not available on PATH. Run this on a Proxmox host."
}

$rawBase = Get-RawBaseFromRepoUrl -Repo $RepoUrl
$schemaUrl = "$rawBase/$Ref/profiles/profiles.json"
$templateUrl = "$rawBase/$Ref/cloud-init/templates/$Profile.yaml.template"

$schemaText = Get-RemoteText -Url $schemaUrl
try {
  $schema = $schemaText | ConvertFrom-Json
} catch {
  Die "Failed to parse profiles.json from $schemaUrl"
}

$profiles = @()
if ($schema.profiles) {
  $profiles = @($schema.profiles)
}
if ($profiles.Count -eq 0) {
  Die "profiles.json does not contain a profiles array."
}

$profileSchema = $profiles | Where-Object { $_.name -eq $Profile } | Select-Object -First 1
if (-not $profileSchema) {
  Die "Profile '$Profile' not found in profiles.json."
}

$required = @()
if ($profileSchema.required_vars) {
  $required = @($profileSchema.required_vars)
}

$optionalDefaults = @{}
if ($profileSchema.optional_vars) {
  foreach ($var in $profileSchema.optional_vars) {
    if ($var.name) {
      $optionalDefaults[$var.name] = [string]$var.default
    }
  }
}

$secretVars = @()
if ($profileSchema.required_vars) {
  $secretVars += @($profileSchema.required_vars | Where-Object { $_.secret -eq $true } | ForEach-Object { $_.name })
}
if ($profileSchema.optional_vars) {
  $secretVars += @($profileSchema.optional_vars | Where-Object { $_.secret -eq $true } | ForEach-Object { $_.name })
}

$values = @{
  PROFILE = $Profile
  REPO_URL = $RepoUrl
  COMPOSE_PROJECT_DIR = $ComposeProjectDir
  EDGE_NETWORK_NAME = $EdgeNetworkName
  APP_IMAGE = $AppImage
  ZEROTIER_NETWORK_ID = $ZeroTierNetworkId
  CLOUDFLARE_TUNNEL_TOKEN = $null
}

if ($optionalDefaults.ContainsKey('COMPOSE_PROJECT_DIR') -and [string]::IsNullOrWhiteSpace($values.COMPOSE_PROJECT_DIR)) {
  $values.COMPOSE_PROJECT_DIR = $optionalDefaults['COMPOSE_PROJECT_DIR']
}
if ($optionalDefaults.ContainsKey('EDGE_NETWORK_NAME') -and [string]::IsNullOrWhiteSpace($values.EDGE_NETWORK_NAME)) {
  $values.EDGE_NETWORK_NAME = $optionalDefaults['EDGE_NETWORK_NAME']
}

$secureTokenPlain = Get-PlainText -Secure $CloudflareTunnelToken
if (-not [string]::IsNullOrWhiteSpace($secureTokenPlain)) {
  $values.CLOUDFLARE_TUNNEL_TOKEN = $secureTokenPlain
}

foreach ($var in $required) {
  $key = $var.name
  if ([string]::IsNullOrWhiteSpace($key)) {
    continue
  }
  if ($secretVars -contains $key) {
    if ([string]::IsNullOrWhiteSpace($values[$key])) {
      $secure = Read-Host -Prompt "$key (secret)" -AsSecureString
      $plain = Get-PlainText -Secure $secure
      if ([string]::IsNullOrWhiteSpace($plain)) {
        Die "Required secret '$key' was not provided."
      }
      $values[$key] = $plain
      Write-Info "Collected secret '$key'."
    }
  } else {
    if ([string]::IsNullOrWhiteSpace([string]$values[$key])) {
      $answer = Read-Host -Prompt "$key"
      if ([string]::IsNullOrWhiteSpace($answer)) {
        Die "Required value '$key' was not provided."
      }
      $values[$key] = $answer
      Write-Info "Collected '$key'."
    }
  }
}

$templateText = Get-RemoteText -Url $templateUrl
$rendered = Render-Template -Template $templateText -Values $values

if ([string]::IsNullOrWhiteSpace($rendered) -or ($rendered -notmatch 'cloud-config')) {
  Die "Rendered cloud-init template is empty or missing cloud-config."
}

Ensure-SnippetsPath -Path $SnippetsPath

$snippetFile = Join-Path $SnippetsPath "ci-$Profile-$VmId.yaml"
$versionFile = Join-Path $SnippetsPath "ci-$Profile-$VmId.version"

Write-Info "Writing snippet: $snippetFile"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($snippetFile, $rendered, $utf8NoBom)

$timestamp = (Get-Date).ToString('o')
$versionContent = "ref=$Ref`ntimestamp=$timestamp`n"
[System.IO.File]::WriteAllText($versionFile, $versionContent, $utf8NoBom)

Write-Info "Cloning template $TemplateId -> VM $VmId ($Name)"
Invoke-Qm @('clone', $TemplateId, $VmId, '--name', $Name, '--full', 'true')

Write-Info "Configuring VM resources"
Invoke-Qm @('set', $VmId, '--cores', $Cores, '--memory', $MemoryMb)
Invoke-Qm @('set', $VmId, '--net0', "virtio,bridge=$Bridge")
Invoke-Qm @('set', $VmId, '--agent', 'enabled=1')

$cfg = & qm config $VmId 2>$null
if ($cfg -match '^ide2:\s+') {
  Write-Info "Cloud-init drive already present on ide2; leaving as-is"
} else {
  $existingCi = "$Storage:vm-$VmId-cloudinit"
  & pvesm path $existingCi *> $null
  if ($LASTEXITCODE -eq 0) {
    Write-Info "Found existing cloud-init volume ($existingCi); attaching on ide2"
    Invoke-Qm @('set', $VmId, '--ide2', "$existingCi,media=cdrom")
  } else {
    Invoke-Qm @('set', $VmId, '--ide2', "$Storage:cloudinit")
  }
}

Invoke-Qm @('set', $VmId, '--boot', 'order=scsi0;ide2')

$cicustom = "$SnippetsStorageId:snippets/ci-$Profile-$VmId.yaml"
Invoke-Qm @('set', $VmId, '--cicustom', "user=$cicustom")

Write-Info "Starting VM $VmId"
Invoke-Qm @('start', $VmId)

Write-Host ""
Write-Host "Next steps (on the VM):"
Write-Host "  cloud-init status --long"
Write-Host "  sudo tail -n 200 /var/log/cloud-init-output.log"
Write-Host "  sudo tail -n 200 /var/log/bootstrap.log"
