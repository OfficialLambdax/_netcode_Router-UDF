#include-once
#include "_netcode_AddonCore.au3"


#cs

	Requires the _netcode_AddonCore.au3 UDF and _netcode_Core.au3 UDF.

	TCP-IPv4, for the time being, only.

	All Sockets are non blocking.

	The router will only recv and send data if the send to socket is send ready.
	It pretty much checks the sockets that have something send to the router first
	and then filters them for the corresponding linked sockets that can be send to.

	So the router does not buffer data. Memory usage should therefore be low.

#ce

Global $__net_Router_sAddonVersion = "0.2.3.1"
Global Const $__net_Router_sNetcodeOfficialRepositoryURL = "https://github.com/OfficialLambdax/_netcode_Router-UDF"
Global Const $__net_Router_sNetcodeOfficialRepositoryChangelogURL = "https://github.com/OfficialLambdax/_netcode_Router-UDF/blob/main/%23changelog%20router.txt"
Global Const $__net_Router_sNetcodeVersionURL = "https://raw.githubusercontent.com/OfficialLambdax/_netcode-UDF/main/versions/_netcode_Router.version"


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Router_Startup
; Description ...: Needs to be called in order use the UDF.
; Syntax ........: _netcode_Router_Startup()
; Return values .: True				= If success
;				 : False			= If not
; Errors ........: 1				- UDF already started
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Router_Startup()
	_netcode_Startup()

	Local $arParents = __netcode_Addon_GetSocketList('RouterParents')
	If IsArray($arParents) Then Return SetError(1, 0, False) ; router already started

	__netcode_UDFVersionCheck($__net_Router_sNetcodeVersionURL, $__net_Router_sNetcodeOfficialRepositoryURL, $__net_Router_sNetcodeOfficialRepositoryChangelogURL, '_netcode_Router', $__net_Router_sAddonVersion)

	__netcode_Addon_CreateSocketList('RouterParents')

	; create destination middleman
	__netcode_Addon_RegisterMiddleman('netcode_router', "__netcode_Router_DestinationMiddleman", 'Destination', 2)

	__netcode_Addon_Log(2, 1)

	Return True
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Router_Shutdown
; Description ...: ~ todo
; Syntax ........: _netcode_Router_Shutdown()
; Parameters ....: None
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Router_Shutdown()

;~ 	__netcode_Addon_Log(2, 2)
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Router_Loop
; Description ...: Will accept new clients and receive and send data. Needs to be called frequently in order to relay the data.
; Syntax ........: _netcode_Router_Loop([$hSocket = False])
; Parameters ....: $hSocket             - [optional] When set to a Socket, will only loop the given router socket. Otherwise all.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Router_Loop(Const $hSocket = False)

	if $hSocket Then
		__netcode_Router_Loop($hSocket)
	Else
		Local $arParents = __netcode_Addon_GetSocketList('RouterParents')

		For $i = 0 To UBound($arParents) - 1
			__netcode_Router_Loop($arParents[$i])
		Next
	EndIf

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Router_RegisterRoute
; Description ...: Registers a Route. If the client gives this Identifier then it will be connected to the given IP and Port
; Syntax ........: _netcode_Router_RegisterRoute($sIdentifier, $sRouteToIP, $nRouteToPort)
; Parameters ....: $sIdentifier         - (String) ID not larger then 99 characters
;                  $sRouteToIP          - Route to this IP
;                  $nRouteToPort        - Route to this Port
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Router_RegisterRoute($sIdentifier, $sRouteToIP, $nRouteToPort)

	; check identifier len
	If StringLen($sIdentifier) > 99 Then Return SetError(1, 0, False) ; id to long

	_storageGO_CreateGroup(StringToBinary($sIdentifier))

	; create route
	Local $arDestination[2] = [$sRouteToIP,$nRouteToPort]
	__netcode_Addon_SetVar(StringToBinary($sIdentifier), 'Destination', $arDestination)

	Return True

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Router_SendIdentifier
; Description ...: Sends the given identifier to the given socket that is a router server
; Syntax ........: _netcode_Router_SendIdentifier(Const $hSocket, $sIdentifier[, $bSend = True])
; Parameters ....: $hSocket             - [const] The socket
;                  $sIdentifier         - (String) The identifier
;                  $bSend               - [optional] Set to False if you want the string to be returned instead of send.
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Router_SendIdentifier(Const $hSocket, $sIdentifier, $bSend = True)

	; get and check len
	Local $nLen = StringLen($sIdentifier)
	if $nLen > 99 Then Return SetError(1, 0, False) ; id to long
	if $nLen = 0 Then Return SetError(2, 0, False) ; no id given

	; create id string
	Local $sData = ""
	if $nLen > 9 Then
		$sData = $nLen & $sIdentifier
	Else
		$sData = "0" & $nLen & $sIdentifier
	EndIf

	If $bSend Then
		; send it
		__netcode_TCPSend($hSocket, StringToBinary($sData), False)
		Return True
	EndIf

	Return $sData

EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Router_RemoveRoute
; Description ...: Removes the given route
; Syntax ........: _netcode_Router_RemoveRoute($sIdentifier)
; Parameters ....: $sIdentifier         - (String) The Route identifier
; Return values .: None
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Router_RemoveRoute($sIdentifier)
	Local $arDestination = __netcode_Addon_GetVar(StringToBinary($sIdentifier), 'Destination')
	if Not IsArray($arDestination) Then Return SetError(1, 0, False) ; route doesnt exist

	_storageGO_DestroyGroup(StringToBinary($sIdentifier))
	Return True
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _netcode_Router_Create
; Description ...: Starts a router parent (aka listener) and returns the socket.
; Syntax ........: _netcode_Router_Create($sOpenOnIP, $nOpenOnPort)
; Parameters ....: $sOpenOnIP           - Router is open to this IP (set 0.0.0.0 for everyone)
;                  $nOpenOnPort         - Router is open at this Port
; Return values .: Socket				= If success
;				 : False				= If not
; Errors ........: 1					- Listener could not be started
;				 : 2					- UDF not started yet
; Extendeds .....: See msdn https://docs.microsoft.com/de-de/windows/win32/winsock/windows-sockets-error-codes-2
; Modified ......:
; Remarks .......:
; Example .......: No
; ===============================================================================================================================
Func _netcode_Router_Create($sOpenOnIP, $nOpenOnPort)

	; start listener
	Local $hSocket = __netcode_TCPListen($sOpenOnIP, $nOpenOnPort, Default)
	Local $nError = @error
	if $nError Then
		__netcode_Addon_Log(1, 8, $sOpenOnIP & ':' & $nOpenOnPort)
		Return SetError(1, $nError, False)
	EndIf

	; add to parent list
	If Not __netcode_Addon_AddToSocketList('RouterParents', $hSocket) Then
		__netcode_TCPCloseSocket($hSocket)
		__netcode_Addon_Log(0, 3, $hSocket)
		Return SetError(2, 0, False)
	EndIf

	; create socket lists
	__netcode_Addon_CreateSocketLists_InOutRel($hSocket)

	; specify the middlemans
	__netcode_Addon_SetMiddleman($hSocket, 'netcode_router', 2)

	__netcode_Addon_Log(2, 6, $hSocket, 'netcode_router')

	Return $hSocket

EndFunc





Func __netcode_Router_Loop(Const $hSocket)

	; check for new incoming connections, one per loop
	Local $hIncomingSocket = __netcode_TCPAccept($hSocket)
	If $hIncomingSocket <> -1 Then __netcode_Addon_NewIncomingMiddleman($hSocket, $hIncomingSocket, 2)

	; check the incoming connection middlemans for destinations
	__netcode_Addon_CheckIncomingPendingMiddleman($hSocket, 2)

	; check the outgoing pending connections
	__netcode_Addon_CheckOutgoingPendingMiddleman($hSocket, 2)

	; recv and send
;~ 	__netcode_Addon_RecvAndSend($hSocket, 2)
	__netcode_Addon_RecvAndSendMiddleman($hSocket, 2)

EndFunc

Func __netcode_Router_DestinationMiddleman(Const $hIncomingSocket, $sPosition, $sData)

	; read the len and the maximum id len from the data
	Local $sIdentifier = StringLeft($sData, 101)

	; read the len
	Local $nLen = Number(StringLeft($sIdentifier, 2))
	if $nLen = 0 Then
		__netcode_Addon_Log(2, 29, $hIncomingSocket)
		Return False ; could not read the destination id len
	EndIf

	; read the id
	$sIdentifier = StringMid($sIdentifier, 3, $nLen)

	; get the destination ip and port for that route
	Local $arIPAndPort = __netcode_Addon_GetVar(StringToBinary($sIdentifier), 'Destination')
	If Not IsArray($arIPAndPort) Then
		__netcode_Addon_Log(2, 28, $sIdentifier, $hIncomingSocket)
		Return False ; unknown id
	EndIf

	; cut the id and len from the left data
	$sData = StringTrimLeft($sData, 2 + StringLen($sIdentifier))

	; build destination array
	if StringLen($sData) > 0 Then
		Local $arDestination[3]
		$arDestination[0] = $arIPAndPort[0]
		$arDestination[1] = $arIPAndPort[1]

		; forward the left data to the destination
		$arDestination[2] = $sData
	Else
		Local $arDestination[2]
		$arDestination[0] = $arIPAndPort[0]
		$arDestination[1] = $arIPAndPort[1]
	EndIf

	__netcode_Addon_Log(2, 27, $sIdentifier, $hIncomingSocket)

	; return it
	Return $arDestination

EndFunc
