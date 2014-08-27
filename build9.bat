rem #Imago <imagotrigger@gmail.com> build allegiance solution using VS2008
rem build9.bat <Flavor> <Action> (ex. >build9.bat FZRetail rebuild)

call "C:\Program Files (x86)\Microsoft Visual Studio 9.0\VC\vcvarsall.bat" x86
set INCLUDE=C:\Program Files (x86)\Microsoft Visual Studio 9.0\VC\ATLMFC\INCLUDE;C:\Program Files (x86)\Microsoft Visual Studio 9.0\VC\INCLUDE;C:\Program Files\Microsoft SDKs\Windows\v6.0A\include;C:\Program Files (x86)\Microsoft DirectX SDK (February 2010)\Include
set LIB=C:\Program Files (x86)\Microsoft Visual Studio 9.0\VC\ATLMFC\LIB;C:\Program Files (x86)\Microsoft Visual Studio 9.0\VC\LIB;C:\Program Files\Microsoft SDKs\Windows\v6.0A\lib;C:\Program Files (x86)\Microsoft DirectX SDK (February 2010)\Lib\x86
msbuild C:\build\FAZR6\VS2008\Allegiance.sln /nologo /p:"VCBuildAdditionalOptions=/useenv" /p:Configuration=%1 /t:%2