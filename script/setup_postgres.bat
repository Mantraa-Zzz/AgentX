@echo off
@REM 设置颜色代码
set GREEN=[32m
set YELLOW=[33m
set RED=[31m
set NC=[0m

@REM 获取项目根目录的绝对路径
for %%i in ("%~dp0..") do set "PROJECT_ROOT=%%~fi"

@REM 设置SQL目录
set "SQL_DIR=%PROJECT_ROOT%\docs\sql"

@REM 参数设置
set CONTAINER_NAME=agentx-postgres
set DB_NAME=agentx
set DB_USER=postgres
set DB_PASSWORD=postgres
set DB_PORT=5432
set HOST_PORT=5432
set INIT_SQL=%SQL_DIR%\init.sql

echo %GREEN%AgentX PostgreSQL 数据库初始化脚本%NC%
echo ===============================================
echo 容器名称: %CONTAINER_NAME%
echo 数据库名称: %DB_NAME%
echo 数据库用户: %DB_USER%
echo 数据库端口: %DB_PORT%
echo 主机映射端口: %HOST_PORT%
echo SQL文件路径: %INIT_SQL%
echo ===============================================

@REM 检查 Docker 是否已安装
docker --version > nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%错误: Docker 未安装，请先安装 Docker%NC%
    exit /b 1
)

@REM 检查 SQL 文件是否存在
if not exist "%INIT_SQL%" (
    echo %RED%错误: 初始化 SQL 文件 '%INIT_SQL%' 不存在%NC%
    exit /b 1
)

@REM 检查容器是否已存在
docker ps -a | findstr "%CONTAINER_NAME%" > nul
if %ERRORLEVEL% equ 0 (
    echo %YELLOW%警告: 容器 '%CONTAINER_NAME%' 已存在%NC%
    set /p REPLY=是否停止并删除已有容器? [y/N] 
    if /i "%REPLY%"=="y" (
        echo 停止容器...
        docker stop "%CONTAINER_NAME%" > nul
        echo 删除容器...
        docker rm "%CONTAINER_NAME%" > nul
    ) else (
        echo 操作取消
        exit /b 0
    )
)

@REM 检查端口是否已被占用
netstat -ano | findstr ":%HOST_PORT%" | findstr "LISTENING" > nul
if %ERRORLEVEL% equ 0 (
    echo %YELLOW%警告: 端口 %HOST_PORT% 已被占用%NC%
    set /p REPLY=是否使用不同的端口? [y/N] 
    if /i "%REPLY%"=="y" (
        set /p HOST_PORT=请输入新的端口号: 
    ) else (
        echo 操作取消
        exit /b 0
    )
)

echo %GREEN%启动 PostgreSQL 容器...%NC%
docker run --name "%CONTAINER_NAME%" ^
    -e POSTGRES_USER="%DB_USER%" ^
    -e POSTGRES_PASSWORD="%DB_PASSWORD%" ^
    -e POSTGRES_DB="%DB_NAME%" ^
    -p "%HOST_PORT%:%DB_PORT%" ^
    -v "%SQL_DIR%:/docker-entrypoint-initdb.d" ^
    -d ankane/pgvector:latest

@REM 检查容器是否成功启动
if %ERRORLEVEL% neq 0 (
    echo %RED%错误: 容器启动失败%NC%
    exit /b 1
)

echo %GREEN%等待 PostgreSQL 启动...%NC%
timeout /t 5 /nobreak > nul

@REM 确认 PostgreSQL 是否已准备好接受连接
set RETRIES=10
:RETRY_LOOP
if %RETRIES% leq 0 goto RETRY_END
docker exec "%CONTAINER_NAME%" pg_isready -U "%DB_USER%" -d "%DB_NAME%" > nul 2>&1
if %ERRORLEVEL% equ 0 goto RETRY_END
echo 等待 PostgreSQL 启动中，剩余尝试次数: %RETRIES%
set /a RETRIES-=1
timeout /t 3 /nobreak > nul
goto RETRY_LOOP
:RETRY_END

if %RETRIES% leq 0 (
    echo %RED%错误: PostgreSQL 启动超时%NC%
    exit /b 1
)

echo %GREEN%PostgreSQL 容器已成功启动！%NC%
echo 容器名称: %CONTAINER_NAME%
echo 连接信息:
echo   主机: localhost
echo   端口: %HOST_PORT%
echo   用户: %DB_USER%
echo   密码: %DB_PASSWORD%
echo   数据库: %DB_NAME%
echo   连接URL: jdbc:postgresql://localhost:%HOST_PORT%/%DB_NAME%
echo.
echo 你可以使用以下命令连接到数据库:
echo   docker exec -it %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME%
echo.
echo %GREEN%数据库初始化完成！%NC% 