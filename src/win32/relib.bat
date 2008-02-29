set MLUALIB_TARGET=d:\tmp\mlualib
xcopy /E /Y lib %MLUALIB_TARGET%
lua win32\precompile.lua %MLUALIB_TARGET%
