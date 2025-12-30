@echo off
echo FramePack-Studio Setup Script for RTX 40xx/50xx GPUs
echo Using PyTorch 2.7.0 with CUDA 12.8
echo ============================================
setlocal enabledelayedexpansion

REM Check if Python is installed
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Python is not installed or not in your PATH. Please install Python and try again.
    goto end
)

REM Check Python version
echo Checking Python version...
echo Python versions 3.10-3.11 are recommended (3.10.x or 3.11.x).
echo Python 3.12+ may have compatibility issues with some packages.
echo You currently have:
python -V
echo.
set /p continue_choice="Do you want to continue with this Python version? [Y/N]: "
if /i not "!continue_choice!" == "Y" (
    echo Please install Python 3.11.x from https://www.python.org/downloads/
    goto end
)

REM Check for existing venv
if exist "%cd%\venv" (
    echo Virtual Environment already exists.
    set /p choice="Do you want to delete and recreate it? [Y/N]: "
    if /i "!choice!" == "Y" (
        echo Deleting existing venv...
        rmdir /s /q "%cd%\venv"
        goto makevenv
    ) else (
        echo Keeping existing venv. Installing packages...
        goto checkgpu
    )
) else (
    goto makevenv
)

:makevenv
echo.
echo Creating Virtual Environment...
python -m venv venv
if %errorlevel% neq 0 (
    echo Error: Failed to create virtual environment.
    goto end
)

echo Upgrading pip in Virtual Environment...
"%cd%\venv\Scripts\python.exe" -m pip install --upgrade pip

:checkgpu
REM Check for Nvidia GPU
where nvidia-smi >nul 2>&1
if %errorlevel% neq 0 (
    echo Warning: nvidia-smi not found. Cannot detect GPU.
    echo Continuing with installation anyway...
    goto installpytorch
)

echo.
echo Detecting GPU...
for /F "tokens=* skip=1" %%n in ('nvidia-smi --query-gpu=name') do set GPU_NAME=%%n && goto gpuchecked

:gpuchecked
echo Detected: %GPU_NAME%
echo.

:installpytorch
echo Installing PyTorch 2.7.0 with CUDA 12.8...
echo This may take several minutes depending on your internet connection...
"%cd%\venv\Scripts\pip.exe" install torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url https://download.pytorch.org/whl/cu128

if %errorlevel% neq 0 (
    echo Error: Failed to install PyTorch. Please check your internet connection and try again.
    goto end
)

echo.
echo PyTorch 2.7.0 installed successfully!
echo.

REM Get Python version for acceleration packages
for /f "delims=" %%A in ('"%cd%\venv\Scripts\python.exe" -V') do set "pyv=%%A"
for /f "tokens=2 delims= " %%A in ("%pyv%") do set pyv=%%A
set pyv=%pyv:.=%
set pyv=%pyv:~0,3%

REM Ask about acceleration packages
echo ============================================
echo Optional: Install acceleration packages?
echo These can significantly speed up generation:
echo.
echo 1) Sage Attention (recommended for RTX 40xx/50xx)
echo 2) Flash Attention (alternative acceleration)
echo 3) BOTH (maximum performance)
echo 4) Skip (no acceleration packages)
echo.
set /p accel_choice="Enter your choice [1-4]: "

if "!accel_choice!" == "1" goto install_sage
if "!accel_choice!" == "2" goto install_flash
if "!accel_choice!" == "3" (
    set install_both=Y
    goto install_sage
)
goto requirements

:install_sage
echo.
echo Installing Sage Attention...
echo Installing triton-windows...
"%cd%\venv\Scripts\pip.exe" install "triton-windows<3.4" --force-reinstall

if %errorlevel% neq 0 (
    echo Warning: Failed to install triton-windows. Skipping Sage Attention.
    if "!install_both!" == "Y" goto install_flash
    goto requirements
)

echo Downloading triton libraries for Python %pyv%...
if %pyv% == 310 (
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://github.com/woct0rdho/triton-windows/releases/download/v3.0.0-windows.post1/python_3.10.11_include_libs.zip', 'triton-lib.zip')"
)
if %pyv% == 311 (
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://github.com/woct0rdho/triton-windows/releases/download/v3.0.0-windows.post1/python_3.11.9_include_libs.zip', 'triton-lib.zip')"
)
if %pyv% == 312 (
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://github.com/woct0rdho/triton-windows/releases/download/v3.0.0-windows.post1/python_3.12.7_include_libs.zip', 'triton-lib.zip')"
)

if exist "triton-lib.zip" (
    echo Extracting triton libraries...
    powershell Expand-Archive -Path '%cd%\triton-lib.zip' -DestinationPath '%cd%\venv\Scripts\' -force
    del triton-lib.zip
    echo Triton libraries installed successfully.
) else (
    echo Warning: Could not download triton libraries for Python %pyv%.
    echo Sage Attention may not work properly.
)

echo Installing Sage Attention for PyTorch 2.7.0...
"%cd%\venv\Scripts\pip.exe" install "https://github.com/woct0rdho/SageAttention/releases/download/v2.1.1-windows/sageattention-2.1.1+cu128torch2.7.0-cp%pyv%-cp%pyv%-win_amd64.whl" --force-reinstall

if %errorlevel% neq 0 (
    echo Warning: Failed to install Sage Attention. Continuing anyway...
)

if "!install_both!" == "Y" goto install_flash
goto requirements

:install_flash
echo.
echo Installing Flash Attention...
"%cd%\venv\Scripts\pip.exe" install "https://huggingface.co/lldacing/flash-attention-windows-wheel/resolve/main/flash_attn-2.7.4.post1%%2Bcu128torch2.7.0cxx11abiFALSE-cp%pyv%-cp%pyv%-win_amd64.whl?download=true"

if %errorlevel% neq 0 (
    echo Warning: Failed to install Flash Attention. Continuing anyway...
)

:requirements
echo.
echo ============================================
echo Installing remaining required packages...
echo This will install all dependencies including basicsr, gfpgan, realesrgan, gradio, and more...
echo This may take several minutes...
echo.

if exist "%cd%\requirements.txt" (
    "%cd%\venv\Scripts\pip.exe" install -r requirements.txt
    if %errorlevel% neq 0 (
        echo Warning: Some packages failed to install. Check the output above.
        echo You may need to install missing packages manually.
    ) else (
        echo All requirements installed successfully!
    )
) else (
    echo Error: requirements.txt not found. Cannot install dependencies.
    goto end
)

echo.
echo ============================================
echo Verifying installation...
echo.

REM Verify PyTorch installation
echo Checking PyTorch...
"%cd%\venv\Scripts\python.exe" -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA Available: {torch.cuda.is_available()}'); print(f'CUDA Version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}')"

echo.
echo Checking key packages...
"%cd%\venv\Scripts\python.exe" -c "import gradio; import diffusers; import transformers; print('Gradio: OK'); print('Diffusers: OK'); print('Transformers: OK')"

echo.
echo ============================================
echo Setup complete!
echo.
echo Python Environment: Python %pyv:~0,1%.%pyv:~1,1%%pyv:~2,1%
echo PyTorch Version: 2.7.0 + CUDA 12.8
echo.
echo To start FramePack-Studio:
echo 1. Run: start.bat
echo 2. Open your browser to: http://localhost:7860
echo.
echo The application will download AI models on first run.
echo This may take 10-20 minutes depending on your internet speed.
echo.

:end
echo Press any key to exit...
pause >nul
