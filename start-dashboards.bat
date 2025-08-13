@echo off
echo Starting Kubernetes Dashboard and eShop services...
echo.

echo Starting Aspire Dashboard on http://localhost:18888
start /B kubectl port-forward service/aspire-dashboard 18888:18888

echo Starting eShop WebApp on http://localhost:8080
start /B kubectl port-forward service/webapp 8080:8080

echo Starting Official Kubernetes Dashboard on https://localhost:8443
start /B kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443

echo Starting Custom Dashboard on http://localhost:8003
start /B kubectl port-forward service/simple-k8s-dashboard 8003:80

echo Starting PgWeb (PostgreSQL Web Interface) on http://localhost:8081
start /B kubectl port-forward service/pgweb 8081:8081

echo Starting PgAdmin (PostgreSQL Admin) on http://localhost:8082
start /B kubectl port-forward service/pgadmin 8082:80

echo.
echo ✅ All services started!
echo.
echo Access your services:
echo - Official K8s Dashboard: https://localhost:8443 (needs token)
echo - Custom Dashboard:       http://localhost:8003
echo - Aspire Dashboard:       http://localhost:18888  
echo - eShop WebApp:           http://localhost:8080
echo - PgWeb (DB Browser):     http://localhost:8081
echo - PgAdmin (DB Admin):     http://localhost:8082 (admin@admin.com / admin)
echo - Grafana (Monitoring):   http://localhost:3000 (admin / admin)
echo.
echo Press any key to exit...
pause >nul