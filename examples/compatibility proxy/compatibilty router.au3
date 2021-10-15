#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
;~ #AutoIt3Wrapper_Run_Au3Stripper=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;~ #AutoIt3Wrapper_Au3stripper_OnError=ForceUse ; not working
#include "..\..\..\_netcode_Proxy.au3"
#include "..\..\..\_netcode_Router.au3"
#cs
	Proxy Compatibility for Router if you dont have access to the Clients Source
	to send the required identifier.
	This example is only usefull for a single Service


	Define the Globals below to where the Router is and the identifier of the Service
	you try to reach.

	Example:
	Lets say you have a Minecraft Server at port 25565 that is blocked by the Firewall because
	you dont want it to be accessible from the Internet. In the example you have the Proxy on the
	same machine as the Minecraft Client.

	Router code:

	_netcode_Startup()
	Local $hRouterSocket = _netcode_RouterStartServer(port open to the internet here)
	_netcode_RouterAddRoute($hRouterSocket, "ip to the minecraft server", 25565, "minecraft")
	While True
		_netcode_RouterLoop()
	WEnd

	Proxy code:

	Global $__sRouteToIP = "ip to the router"
	Global $__sRouteToPort = port of the router thats open to the internet
	Global $__sRouteIdentifier = "minecraft"


	Remarks:
		- _netcode always tries to fully utilize the thread it is running in. So even if nothing
		is going on the thread will run on 100 %. Thats why in this example there is a Sleep(10) in the
		Main Loop. If you encounter lag try to remove the sleep. Beaware Sleep() can not be lower then 10 ms.

		- Certain features _netcode comes with are not compatible with the Router in generall yet, like the Socket
		Linking feature. This compatibility Router makes them compatible. Atleast as of now.

#ce

Global $__sRouteToIP = "127.0.0.1" ; ip of the Router
Global $__sRouteToPort = 1226 ; port of the Router
Global $__sRouteIdentifier = "test" ; identifier of the destination behind the Router


_netcode_Startup()
_netcode_ProxySetConsoleLogging(True)

Local $hProxySocket = _netcode_SetupTCPProxy("0.0.0.0", 1225)
_netcode_ProxySetMiddleman($hProxySocket, 1, "__netcode_ProxyRouterOnConnection")

While Sleep(10)
	_netcode_ProxyLoop()
WEnd


Func __netcode_ProxyRouterOnConnection(Const $hSocket, $nWhere)
	Local $arMiddleman[3] = [$__sRouteToIP,$__sRouteToPort,_netcode_RouterSendIdentifier(0, $__sRouteIdentifier, True)]
;~ 	Local $arMiddleman[2] = [$__sRouteToIP,$__sRouteToPort]
	Return $arMiddleman
EndFunc