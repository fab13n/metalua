
cd binlibs
del *.dll *.exp *.lib *.obj
cd ..

cd compiler
del *.luac 
cd ..

cd lua
del *.dll *.exp *.lib *.obj *.exe
cd ..

cd win32
del *.dll *.exp *.lib *.obj
cd ..

del mlua_setenv.bat