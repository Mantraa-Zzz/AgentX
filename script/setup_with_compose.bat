@echo off
setlocal enabledelayedexpansion

:: 设置颜色代码
set "GREEN=[32m"
set "YELLOW=[33m"
set "RED=[31m"
set "BLUE=[34m"
set "NC=[0m"

:: 获取项目根目录的绝对路径
pushd %~dp0\..
set "PROJECT_ROOT=%CD%"
popd
set "SCRIPT_DIR=%PROJECT_ROOT%\script"
set "SQL_DIR=%PROJECT_ROOT%\docs\sql"

:: 切换到脚本目录
cd "%SCRIPT_DIR%"

echo %GREEN%AgentX PostgreSQL 数据库初始化脚本 (Docker Compose 版)%NC%
echo ===============================================
echo 数据库名称: agentx
echo 数据库用户: postgres
echo 数据库密码: postgres
echo 端口: 5432
echo SQL目录: %SQL_DIR%
echo ===============================================

:: 检查是否安装了 Docker
where docker >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo %RED%Error: Docker is not installed. Please install Docker Desktop for Windows first.%NC%
    exit /b 1
)

:: 检查是否安装了 Docker Compose
where docker-compose >nul 2>nul
if %ERRORLEVEL% neq 0 (
    docker compose version >nul 2>nul
    if %ERRORLEVEL% neq 0 (
        echo %RED%Error: Docker Compose is not installed. Please install Docker Compose first.%NC%
        exit /b 1
    )
)

:: 检查 SQL 文件是否存在
if not exist "%SQL_DIR%\init.sql" (
    echo %RED%Error: SQL file '%SQL_DIR%\init.sql' not found!%NC%
    exit /b 1
)

:: 检查 docker-compose.yml 文件是否存在
if not exist "docker-compose.yml" (
    echo %RED%Error: docker-compose.yml not found!%NC%
    exit /b 1
)

:: 检查容器是否已存在
docker ps -a | findstr "agentx-postgres" >nul
if %ERRORLEVEL% equ 0 (
    echo %YELLOW%Warning: Container 'agentx-postgres' already exists%NC%
    set /p REPLY="Do you want to remove it? (y/N) "
    if /i "!REPLY!"=="y" (
        echo Removing existing container...
        
        :: 尝试使用 docker compose 停止并删除容器
        docker compose version >nul 2>nul
        if %ERRORLEVEL% equ 0 (
            docker compose down -v
        ) else (
            docker-compose down -v
        )
        
        :: 如果 docker-compose 失败，使用 docker 命令删除
        docker ps -a | findstr "agentx-postgres" >nul
        if %ERRORLEVEL% equ 0 (
            echo Using docker command to stop container...
            docker stop agentx-postgres >nul
            echo Removing container...
            docker rm agentx-postgres >nul
        )
    ) else (
        echo Operation cancelled
        exit /b 0
    )
)

echo %GREEN%Starting PostgreSQL container...%NC%

:: 使用 docker compose 或 docker-compose 根据环境支持
docker compose version >nul 2>nul
if %ERRORLEVEL% equ 0 (
    docker compose up -d
) else (
    docker-compose up -d
)

if %ERRORLEVEL% neq 0 (
    echo %RED%Error: Failed to start container%NC%
    exit /b 1
)

echo %GREEN%Waiting for PostgreSQL to be ready...%NC%
timeout /t 5 /nobreak >nul

:: 等待容器健康检查
set /a retries=10
:WAIT_LOOP
if %retries% leq 0 (
    echo %RED%Error: PostgreSQL startup timeout%NC%
    exit /b 1
)

docker exec agentx-postgres pg_isready -U postgres -d agentx >nul 2>nul
if %ERRORLEVEL% neq 0 (
    set /a retries-=1
    echo Waiting for PostgreSQL to start, remaining attempts: %retries%
    timeout /t 3 /nobreak >nul
    goto WAIT_LOOP
)

echo.
echo %GREEN%PostgreSQL container started successfully!%NC%
echo Container name: agentx-postgres
echo Connection Information:
echo   Host: localhost
echo   Port: 5432
echo   User: postgres
echo   Password: postgres
echo   Database: agentx
echo   Connection URL: jdbc:postgresql://localhost:5432/agentx
echo.
echo You can connect to the database using:
echo   docker exec -it agentx-postgres psql -U postgres -d agentx
echo.
echo %YELLOW%Usage Guide:%NC%
echo   Start container: cd script ^&^& setup_with_compose.bat
echo   Stop container: cd script ^&^& docker-compose down
echo   Check container status: docker ps
echo   View container logs: docker logs agentx-postgres
echo.
echo %GREEN%Database initialization complete!%NC%

endlocal 