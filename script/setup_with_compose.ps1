# PowerShell script for setting up PostgreSQL with Docker Compose
# Color definitions for terminal output
$ESC = [char]27
$Colors = @{
    Red = "$ESC[31m"
    Green = "$ESC[32m"
    Yellow = "$ESC[33m"
    Blue = "$ESC[34m"
    Reset = "$ESC[0m"
}

function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Color
    )
    Write-Host "$($Colors[$Color])$Message$($Colors['Reset'])"
}

function Test-CommandExists {
    param(
        [string]$Command
    )
    try {
        Get-Command $Command -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Check if Docker is installed
if (-not (Test-CommandExists "docker")) {
    Write-ColorMessage "Docker is not installed. Please install Docker Desktop for Windows first." "Red"
    exit 1
}

# Check if Docker Compose is available
if (-not (Test-CommandExists "docker-compose")) {
    Write-ColorMessage "Docker Compose is not installed. Please install Docker Compose first." "Red"
    exit 1
}

# Check if docker-compose.yml exists
if (-not (Test-Path "docker-compose.yml")) {
    Write-ColorMessage "docker-compose.yml not found in current directory!" "Red"
    exit 1
}

# Check if SQL files exist
$sqlPath = "../docs/sql"
if (-not (Test-Path $sqlPath)) {
    Write-ColorMessage "SQL directory not found at $sqlPath!" "Red"
    exit 1
}

# Check if container already exists
$containerName = "agentx-postgres"
$existingContainer = docker ps -a --filter "name=$containerName" --format "{{.Names}}"

if ($existingContainer) {
    Write-ColorMessage "Container $containerName already exists." "Yellow"
    $response = Read-Host "Do you want to remove it? (y/N)"
    if ($response -eq "y" -or $response -eq "Y") {
        Write-ColorMessage "Removing existing container..." "Blue"
        docker rm -f $containerName
    } else {
        Write-ColorMessage "Exiting without making changes." "Yellow"
        exit 0
    }
}

# Start the container with docker-compose
Write-ColorMessage "Starting PostgreSQL container with Docker Compose..." "Blue"
docker-compose up -d

# Wait for container to be healthy
Write-ColorMessage "Waiting for PostgreSQL to be ready..." "Blue"
$healthy = $false
$attempts = 0
$maxAttempts = 30

while (-not $healthy -and $attempts -lt $maxAttempts) {
    $status = docker inspect --format "{{.State.Health.Status}}" $containerName
    if ($status -eq "healthy") {
        $healthy = $true
    } else {
        $attempts++
        Start-Sleep -Seconds 2
    }
}

if (-not $healthy) {
    Write-ColorMessage "PostgreSQL container failed to become healthy within timeout." "Red"
    Write-ColorMessage "Please check the logs with: docker logs $containerName" "Yellow"
    exit 1
}

# Display success message and connection information
Write-ColorMessage "`nPostgreSQL is now running and ready for connections!" "Green"
Write-ColorMessage "Connection Information:" "Blue"
Write-ColorMessage "  Host: localhost" "Yellow"
Write-ColorMessage "  Port: 5432" "Yellow"
Write-ColorMessage "  Database: agentx" "Yellow"
Write-ColorMessage "  Username: postgres" "Yellow"
Write-ColorMessage "  Password: postgres" "Yellow"
Write-ColorMessage "`nTo stop the container, run: docker-compose down" "Blue" 