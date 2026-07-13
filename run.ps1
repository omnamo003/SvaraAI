<#
.SYNOPSIS
  Orchestration script for ShivaAI local development environment.
.DESCRIPTION
  Provides simple commands for starting services, building containers, running tests, linting, and inspecting logs.
.EXAMPLE
  .\run.ps1 start
  .\run.ps1 test backend
#>

param(
    [Parameter(Position = 0)]
    [string]$Action = "help",

    [Parameter(Position = 1)]
    [string]$Target = "all"
)

# Colors helper
function Write-Header ($text) {
    Write-Host "`n--- $text ---" -ForegroundColor Cyan
}

function Write-Success ($text) {
    Write-Host "[SUCCESS] $text" -ForegroundColor Green
}

function Write-Info ($text) {
    Write-Host "[INFO] $text" -ForegroundColor Yellow
}

function Write-Danger ($text) {
    Write-Host "[ERROR] $text" -ForegroundColor Red
}

switch ($Action) {
    "start" {
        Write-Header "Starting ShivaAI Local Services"
        docker compose up -d
        Write-Success "Services started. Use '.\run.ps1 status' to verify."
    }

    "stop" {
        Write-Header "Stopping ShivaAI Local Services"
        docker compose down
        Write-Success "Services stopped."
    }

    "restart" {
        Write-Header "Restarting ShivaAI Local Services"
        if ($Target -eq "all") {
            docker compose restart
        } else {
            docker compose restart $Target
        }
        Write-Success "Restart sequence complete."
    }

    "build" {
        Write-Header "Building Container Images"
        if ($Target -eq "all") {
            docker compose build
        } else {
            docker compose build $Target
        }
        Write-Success "Build complete."
    }

    "rebuild" {
        Write-Header "Clean Rebuilding Container Images"
        if ($Target -eq "all") {
            docker compose build --no-cache
        } else {
            docker compose build --no-cache $Target
        }
        Write-Success "Clean build complete."
    }

    "status" {
        Write-Header "ShivaAI Containers Status"
        docker compose ps
    }

    "logs" {
        if ($Target -eq "all") {
            docker compose logs -f --tail 100
        } else {
            docker compose logs -f --tail 100 $Target
        }
    }

    "lint" {
        Write-Header "Linting Codebase (Ruff & ESLint)"
        
        # Python Linting
        Write-Info "Running Ruff Linters..."
        if (Get-Command "ruff" -ErrorAction SilentlyContinue) {
            ruff check .
        } else {
            Write-Danger "Ruff tool is not installed locally. Running inside container..."
            docker compose run --rm backend ruff check .
        }

        # Frontend Linting
        Write-Info "Running Frontend Linters..."
        docker compose run --rm web npm run lint
    }

    "format" {
        Write-Header "Formatting Codebase (Ruff & Prettier)"
        
        # Python Format
        Write-Info "Running Ruff Formatters..."
        if (Get-Command "ruff" -ErrorAction SilentlyContinue) {
            ruff format .
        } else {
            Write-Danger "Ruff tool is not installed locally. Running inside container..."
            docker compose run --rm backend ruff format .
        }

        # Frontend Format
        Write-Info "Running Prettier Formatters..."
        docker compose run --rm web npx prettier --write "src/**/*.{ts,tsx,js,jsx,json,css,md}"
    }

    "test" {
        Write-Header "Running Test Suite"
        if ($Target -eq "all" -or $Target -eq "backend") {
            Write-Info "Running Backend Tests (pytest)..."
            docker compose run --rm backend pytest
        }
        if ($Target -eq "all" -or $Target -eq "worker") {
            Write-Info "Running Worker Tests (pytest)..."
            docker compose run --rm worker pytest
        }
        if ($Target -eq "all" -or $Target -eq "web") {
            Write-Info "Running Frontend Tests (jest)..."
            docker compose run --rm web npm run test
        }
    }

    "clean" {
        Write-Header "Cleaning Up Docker Assets and Volumes"
        docker compose down -v --remove-orphans
        docker system prune -f --volumes
        Write-Success "Cleanup complete."
    }

    "help" {
        Write-Host "ShivaAI Dev Orchestrator Utility" -ForegroundColor Green
        Write-Host "`nUsage:"
        Write-Host "  .\run.ps1 [command] [target]"
        Write-Host "`nCommands:"
        Write-Host "  start           Start all container services in background"
        Write-Host "  stop            Stop and tear down active container services"
        Write-Host "  restart         Restart services (optional target: backend, worker, web, nginx)"
        Write-Host "  build           Build container images (optional target: backend, worker, web, nginx)"
        Write-Host "  rebuild         Rebuild container images from scratch with no-cache"
        Write-Host "  status          Show container system runtime status"
        Write-Host "  logs            Stream container logs (optional target: backend, worker, web, nginx)"
        Write-Host "  lint            Check code for style and syntax warnings"
        Write-Host "  format          Format codebase files automatically"
        Write-Host "  test            Run unit and integration test suites"
        Write-Host "  clean           Clean up container state, cache volumes, and prune assets"
    }

    default {
        Write-Danger "Unknown command: $Action"
        Write-Host "Run '.\run.ps1 help' to see available commands."
    }
}
