#NoTrayIcon
#include "..\..\..\_netcode_Core.au3"


; sample server running at port 1225

_netcode_Startup()

Local $hMyParent = _netcode_TCPListen(1225)

_netcode_SetOption($hMyParent, 'Encryption', True)

_netcode_SetEvent($hMyParent, 'Test', "_Event_Test")


While Sleep(10)
	_netcode_Loop($hMyParent)
WEnd


Func _Event_Test(Const $hSocket, $sText)
	ConsoleWrite("Got Message: " & $sText & @CRLF)
EndFunc
