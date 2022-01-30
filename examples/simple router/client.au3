#NoTrayIcon
#include "..\..\_netcode_Router.au3"


; sample client connecting to port 1226

_netcode_Startup()

Local $hMyClient = _netcode_TCPConnect("127.0.0.1", 1226, True)

_netcode_Router_SendIdentifier($hMyClient, "testroute")

_netcode_AuthToNetcodeServer($hMyClient, "", "", True)


_netcode_TCPSend($hMyClient, 'Test', "hello")

While _netcode_Loop($hMyClient)
	Sleep(10)
WEnd
