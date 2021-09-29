#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;~ #AutoIt3Wrapper_Au3stripper_OnError=ForceUse ; not working
#include "..\..\..\_netcode_Router.au3"

_netcode_Startup()
Local $hSocket = _netcode_RouterStartServer(1226)
_netcode_RouterAddRoute($hSocket, "127.0.0.1", 8080, "test")

While Sleep(10)
	_netcode_RouterLoop()
WEnd