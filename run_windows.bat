@echo off
echo ========================================
echo Flutter Windows 运行脚本
echo ========================================
echo.

echo [1/3] 清理构建缓存...
call flutter clean
echo.

echo [2/3] 获取依赖...
call flutter pub get
echo.

echo [3/3] 运行 Windows 应用...
call flutter run -d windows

pause
