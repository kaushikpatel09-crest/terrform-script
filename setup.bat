@echo off
REM Setup script for Terraform AWS Infrastructure (Windows)
REM This script helps initialize and deploy the infrastructure

setlocal enabledelayedexpansion

REM Check prerequisites
echo.
echo === Checking Prerequisites ===
echo.

where terraform >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: Terraform is not installed
    echo Install from: https://www.terraform.io/downloads
    exit /b 1
)
echo [OK] Terraform installed

where aws >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: AWS CLI is not installed
    echo Install from: https://aws.amazon.com/cli/
    exit /b 1
)
echo [OK] AWS CLI installed

aws sts get-caller-identity >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: AWS credentials not configured
    echo Run: aws configure
    exit /b 1
)
echo [OK] AWS credentials configured

REM Display help
if "%1"=="help" goto :show_help
if "%1"=="--help" goto :show_help
if "%1"=="" goto :show_help

REM Get command and environment
set command=%1
set environment=%2
if "%environment%"=="" set environment=dev

REM Execute command
if "%command%"=="validate" goto :validate
if "%command%"=="plan" goto :plan
if "%command%"=="apply" goto :apply
if "%command%"=="destroy" goto :destroy
if "%command%"=="output" goto :output

echo Unknown command: %command%
echo Run: %0 help
exit /b 1

:validate
echo.
echo === Validating Terraform Configuration ===
echo.
cd terraform
call terraform fmt -check -recursive
if %errorlevel% neq 0 call terraform fmt -recursive
call terraform validate
cd ..
echo.
echo [OK] Configuration is valid
goto :end

:plan
echo.
echo === Planning deployment for %environment% ===
echo.
set /p documentdb_password="Enter DocumentDB master password: "
cd terraform
call terraform plan ^
    -var-file="environments/%environment%.tfvars" ^
    -var="documentdb_master_password=%documentdb_password%" ^
    -out=tfplan ^
    -no-color
cd ..
echo.
echo [OK] Plan saved to terraform\tfplan
goto :end

:apply
echo.
echo === Applying deployment for %environment% ===
echo.
if not exist "terraform\tfplan" (
    echo Error: No plan file found. Run 'plan' first.
    exit /b 1
)
set /p confirm="Are you sure you want to apply? (yes/no): "
if /i not "%confirm%"=="yes" (
    echo Apply cancelled
    exit /b 0
)
cd terraform
call terraform apply tfplan
call terraform output -json > ../outputs-%environment%.json
cd ..
echo.
echo [OK] Deployment complete
echo Outputs saved to outputs-%environment%.json
goto :end

:destroy
echo.
echo === Destroying deployment for %environment% ===
echo WARNING: This will delete all resources!
echo.
set /p confirm="Type environment name to confirm (e.g., %environment%): "
if not "%confirm%"=="%environment%" (
    echo Destroy cancelled
    exit /b 0
)
set /p documentdb_password="Enter DocumentDB master password: "
cd terraform
call terraform destroy ^
    -var-file="environments/%environment%.tfvars" ^
    -var="documentdb_master_password=%documentdb_password%" ^
    -auto-approve
cd ..
echo.
echo [OK] Resources destroyed
goto :end

:output
echo.
echo === Terraform Outputs for %environment% ===
echo.
cd terraform
call terraform output -no-color
cd ..
goto :end

:show_help
echo.
echo Terraform AWS Infrastructure Setup Script
echo.
echo Usage: %0 ^<command^> [environment]
echo.
echo Commands:
echo     validate    Validate Terraform configuration
echo     plan        Plan deployment
echo     apply       Apply deployment
echo     destroy     Destroy deployment
echo     output      Show Terraform outputs
echo     help        Show this help message
echo.
echo Environments:
echo     dev         Development environment (default)
echo     qa          QA environment
echo     stage       Stage environment
echo.
echo Examples:
echo     %0 validate
echo     %0 plan dev
echo     %0 apply dev
echo     %0 output dev
echo     %0 destroy dev
echo.
goto :end

:end
endlocal
