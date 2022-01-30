#NoTrayIcon
#include "..\..\_netcode_Router.au3"

; startup the UDF
_netcode_Router_Startup()

; register a route
_netcode_Router_RegisterRoute("testroute", "127.0.0.1", 1225)

; create router parent
Local $hSocket = _netcode_Router_Create("0.0.0.0", 1226)

; loop it
While True
	_netcode_Router_Loop($hSocket)

	Sleep(10)
WEnd