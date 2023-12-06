@del sahd.o
@del sahd.nes
@del sahd.map.txt
@del sahd.labels.txt
@del sahd.nes.dbg
@del sahd.nes.ram.nl
@del sahd.nes.0.nl
@del sahd.nes.1.nl
@echo.
@echo Compiling...
ca65 sahd.s -g -o sahd.o
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Linking...
ld65 -o sahd.nes -C sahd.cfg sahd.o -m sahd.map.txt -Ln sahd.labels.txt --dbgfile sahd.nes.dbg
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Generating FCEUX debug symbols...
python fceux_symbols.py
@echo.
@echo Success!
@pause
@GOTO endbuild
:failure
@echo.
@echo Build error!
@pause
:endbuild