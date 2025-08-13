@echo off
echo Setting up local performance testing environment...
echo.

echo 🚀 Starting eShop locally with full Aspire Dashboard support
echo This gives you the best performance monitoring experience
echo.

cd /d "C:\Users\Sebastian\source\repos\IggyCloud\eShop\src\eShop.AppHost"

echo Starting AppHost with all services...
echo Access points after startup:
echo - Aspire Dashboard: https://localhost:15888 (full telemetry)
echo - WebApp: https://localhost:7169
echo - All APIs available with metrics
echo.

dotnet run

echo.
echo Performance testing environment ready!
pause