@echo off
echo Starting Official Kubernetes Dashboard...
echo.

echo Setting up port forwarding for Kubernetes Dashboard...
start /B kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443

echo.
echo ✅ Kubernetes Dashboard started!
echo.
echo 🔐 Access the dashboard:
echo URL: https://localhost:8443
echo.
echo 🎫 Authentication Token:
kubectl -n kubernetes-dashboard create token admin-user
echo.
echo 📋 Instructions:
echo 1. Open https://localhost:8443 in your browser
echo 2. Accept the SSL certificate warning
echo 3. Select "Token" authentication method
echo 4. Paste the token above
echo 5. Click "Sign In"
echo.
echo Press any key to exit...
pause >nul