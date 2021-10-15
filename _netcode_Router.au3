#include-once
#include "_netcode_Core.au3"

#cs
	Whats the router?

	In the case that you have setup multiple listeners but you only want to
	forward a single port then you can use the router.

	The router will create a listener on the forwarded port and then
	redirects the incoming packets to the corresponding listeners.

	So you can tunnel all data for multiple servers through this one port.

	To make this work the router requires a single first packet that specifies where to redirect to.
	_netcode_RouterSendIdentifier(socket, identifier) could do that for you.

	In case of you running a _netcode Server behind a router and want to connect to it:
		You first need to _netcode_TCPConnect(ip, port, $bDontAuthAsNetcode = True)
		then _netcode_RouterSendIdentifier(socket, identifier) and then _netcode_AuthToNetcodeServer().

	The Router is compatible with non _netcode servers.
	So in case you dont run a _netcode Server:
		Just send the packet as specified in _netcode_RouterSendIdentifier() first after TCPConnect().

		If you cant modify the client in the way that it sends the required first packet then use the
		_netcode_Proxy UDF. You can set the proxy to send a custom first packet (see example "compatibilty router").
		However between the client and the destination server there then will be two additional hops.
		Even so i did test the proxy, relay in between a game client and the game server
		and found that it worked really well, you could still encounter serious lag.

#ce



Global $__net_router_arServices[0] ; listeners
Global Const $__net_router_UDFVersion = "0.1.1"


; specify parent socket if you want to loop just this one
Func _netcode_RouterLoop(Const $hSocket = False)
	if $hSocket Then Return __netcode_RouterLoop($hSocket)

	For $i = 0 To UBound($__net_router_arServices) - 1
		__netcode_RouterLoop($__net_router_arServices[$i])
	Next
	Return True
EndFunc

Func _netcode_RouterSendIdentifier(Const $hSocket, $sIdentifier, $bDontSendAndReturnData = False)
	if StringLen($sIdentifier) > 9 Then Return SetError(1, 0, False) ; identifier is to long
	if Not $bDontSendAndReturnData Then
		__netcode_TCPSend($hSocket, StringToBinary(StringLen($sIdentifier) & $sIdentifier))
		; ~ todo check for errors
		Return True
	Else
		Return StringLen($sIdentifier) & $sIdentifier
	EndIf
EndFunc

Func _netcode_RouterStartServer($nPort, $sIP = '0.0.0.0', $nMaxPendingConnections = Default)
	Local $hSocket = __netcode_TCPListen($sIP, $nPort, $nMaxPendingConnections)
	if @error Then Return SetError(1, 0, False) ; couldnt setup listener

	__netcode_RouterAddServer($hSocket)
	Return $hSocket
EndFunc

Func _netcode_RouterStopServer(Const $hSocket)

EndFunc

; $sIdentifier len is limited to 9 chars
Func _netcode_RouterAddRoute(Const $hSocket, $sIPTo, $nPortTo, $sIdentifier)
	Local $arIdentifierRoute = __netcode_RouterGetRoute($hSocket, $sIdentifier)
	if IsArray($arIdentifierRoute) Then Return SetError(1, 0, False) ; route already exists

	__netcode_RouterAddRoute($hSocket, $sIPTo, $nPortTo, $sIdentifier)
	Return True
EndFunc

Func _netcode_RouterRemoveRoute(Const $hSocket, $sIdentifier)

EndFunc

; IP white- or blacklist for a router server
Func _netcode_RouterSetIPList(Const $hSocket, $bWhitelist, $arList)

EndFunc


Func __netcode_RouterLoop(Const $hSocket)
	; accept incomming connections and check iplist
	Local $hIncomingSocket = __netcode_TCPAccept($hSocket)
	if $hIncomingSocket <> -1 Then
		ConsoleWrite("Router New Socket @ " & $hIncomingSocket & @CRLF)
		__netcode_RouterAddIncomingSocket($hSocket, $hIncomingSocket)
	EndIf

	; query incoming sockets for route identifier and connect to route, disconnect when fails or invalid identifier
	Local $arClients = _storageS_Read($hSocket, '_netcode_RouterIncomingSockets')
	Local $sRecvBuffer = "", $hOutgoingSocket = 0, $nIDLen = 0
	if UBound($arClients) > 0 Then

		; add select here

		For $i = 0 To UBound($arClients) - 1
			$sRecvBuffer = __netcode_RecvPackages($arClients[$i])
			if @error Then
				ConsoleWrite("Router Incomming Socket @ " & $arClients[$i] & " Disconnected" & @CRLF)
				__netcode_TCPCloseSocket($arClients[$i])
				__netcode_RouterRemoveIncomingSocket($hSocket, $arClients[$i]) ; incomming socket disconnected
				ContinueLoop
			EndIf

			if $sRecvBuffer = "" Then ContinueLoop

			$nIDLen = Int(StringLeft($sRecvBuffer, 1))
			if $nIDLen < 1 or $nIDLen > 9 Then
				ConsoleWrite("Router Incomming Socket @ " & $arClients[$i] & " exceeded identifier len" & @CRLF)
				__netcode_TCPCloseSocket($arClients[$i])
				__netcode_RouterRemoveIncomingSocket($hSocket, $arClients[$i]) ; identifier len exceeded
				ContinueLoop
			EndIf

			Local $arIdentifierRoute = __netcode_RouterGetRoute($hSocket, StringMid($sRecvBuffer, 2, $nIDLen))
			if Not IsArray($arIdentifierRoute) Then
				ConsoleWrite("Router Incomming Socket @ " & $arClients[$i] & " unknown identifier" & @CRLF)
				__netcode_TCPCloseSocket($arClients[$i])
				__netcode_RouterRemoveIncomingSocket($hSocket, $arClients[$i]) ; unknown identifier
				ContinueLoop
			EndIf

			$hOutgoingSocket = __netcode_TCPConnect($arIdentifierRoute[0], $arIdentifierRoute[1])
			if $hOutgoingSocket = -1 Then
				ConsoleWrite("Router Incomming Socket @ " & $arClients[$i] & " Cant connect to route" & @CRLF)
				__netcode_TCPCloseSocket($arClients[$i])
				__netcode_RouterRemoveIncomingSocket($hSocket, $arClients[$i]) ; cant connect to route
				ContinueLoop
			EndIf

			ConsoleWrite("Router @ " & $arClients[$i] & " connected to @ " & $hOutgoingSocket & @CRLF)
			__netcode_RouterAddRouteClient($hSocket, $arClients[$i], $hOutgoingSocket)
			__netcode_RouterRemoveIncomingSocket($hSocket, $arClients[$i])

			If StringLen($sRecvBuffer) > $nIDLen + 1 Then
				$sRecvBuffer = StringTrimLeft($sRecvBuffer, $nIDLen + 1)
				ConsoleWrite("Router Send from @ " & $arClients[$i] & " to @ " & $hOutgoingSocket & " " & Round(StringLen($sRecvBuffer) / 1024, 2) & " KB" & @CRLF)
				__netcode_TCPSend($hOutgoingSocket, StringToBinary($sRecvBuffer))
			EndIf
		Next
	EndIf

	; query established sockets for data and disconnects
	Local $arClients = _storageS_Read($hSocket, '_netcode_RouterClients')
	Local $nArSize = UBound($arClients), $nBytes = 0
	if $nArSize = 0 Then Return

	For $i = 0 To $nArSize - 1
		; incoming to outgoing
		if Not __netcode_RouterRecvAndSend($arClients[$i][0], $arClients[$i][1]) Then
			ConsoleWrite("Router Disconnecting @ " & $arClients[$i][0] & " and @ " & $arClients[$i][1] & @CRLF)
			__netcode_RouterRemoveRouteClient($hSocket, $arClients[$i][0])
			ContinueLoop
		Else
			$nBytes = @extended
			if $nBytes > 0 Then ConsoleWrite("Router Send from @ " & $arClients[$i][0] & " to @ " & $arClients[$i][1] & " " & Round($nBytes / 1024, 2) & " KB" & @CRLF)

		EndIf

		; outgoing to incoming
		If Not __netcode_RouterRecvAndSend($arClients[$i][1], $arClients[$i][0]) Then
			ConsoleWrite("Router Disconnecting @ " & $arClients[$i][0] & " and @ " & $arClients[$i][1] & @CRLF)
			__netcode_RouterRemoveRouteClient($hSocket, $arClients[$i][0])
			ContinueLoop
		Else
			$nBytes = @extended
			if $nBytes > 0 Then ConsoleWrite("Router Send from @ " & $arClients[$i][1] & " to @ " & $arClients[$i][0] & " " & Round($nBytes / 1024, 2) & " KB" & @CRLF)
		EndIf

	Next
EndFunc

Func __netcode_RouterRecvAndSend($hSocket, $hSocketTo)
;~ 	Local $sPackages = __netcode_RelayRecvPackages($hSocket)

	Local $sPackages = _storageS_Read($hSocket, '_netcode_router_buffer')
	if $sPackages = "" Then
		$sPackages = __netcode_RecvPackages($hSocket)
		if @error Then Return False
		if $sPackages = '' Then Return True

		_storageS_Overwrite($hSocket, '_netcode_router_buffer', $sPackages)
	EndIf

	Local $nBytes = __netcode_TCPSend($hSocketTo, StringToBinary($sPackages), False)
	Local $nError = @error
	if $nError <> 10035 Then
		_storageS_Overwrite($hSocket, '_netcode_router_buffer', '')
		$nError = 0
	EndIf
;~ 	if $nError Then MsgBox(0, "", $nError)
	if $nError Then Return False

	Return SetError(0, $nBytes, True)
EndFunc

Func __netcode_RouterAddRouteClient(Const $hSocket, Const $hIncomingSocket, Const $hOutgoingSocket)
	Local $arClients = _storageS_Read($hSocket, '_netcode_RouterClients')
	Local $nArSize = UBound($arClients)
	ReDim $arClients[$nArSize + 1][2]
	$arClients[$nArSize][0] = $hIncomingSocket
	$arClients[$nArSize][1] = $hOutgoingSocket

	_storageS_Overwrite($hSocket, '_netcode_RouterClients', $arClients)

	; add temp storage vars
	_storageS_Overwrite($hIncomingSocket, '_netcode_router_buffer', '')
	_storageS_Overwrite($hOutgoingSocket, '_netcode_router_buffer', '')
EndFunc

Func __netcode_RouterRemoveRouteClient(Const $hSocket, Const $hIncomingSocket)
	Local $arClients = _storageS_Read($hSocket, '_netcode_RouterClients')
	Local $nArSize = UBound($arClients)

	if $nArSize = 1 Then

		__netcode_TCPCloseSocket($hIncomingSocket)
		__netcode_TCPCloseSocket($arClients[0][1])

		; tidy temp storage vars
		_storageS_TidyGroupVars($hIncomingSocket)
		_storageS_TidyGroupVars($arClients[0][1])

		ReDim $arClients[0][2]
		_storageS_Overwrite($hSocket, '_netcode_RouterClients', $arClients)
		Return
	EndIf

	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		if $arClients[$i][0] = $hIncomingSocket Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next
	if $nIndex = -1 Then Return ; what

	__netcode_TCPCloseSocket($hIncomingSocket)
	__netcode_TCPCloseSocket($arClients[$nIndex][1])

	; tidy temp storage vars
	_storageS_TidyGroupVars($hIncomingSocket)
	_storageS_TidyGroupVars($arClients[$nIndex][1])

	$arClients[$nIndex][0] = $arClients[$nArSize - 1][0]
	$arClients[$nIndex][1] = $arClients[$nArSize - 1][1]
	ReDim $arClients[$nArSize - 1][2]

	_storageS_Overwrite($hSocket, '_netcode_RouterClients', $arClients)
EndFunc

Func __netcode_RouterAddIncomingSocket(Const $hSocket, Const $hIncomingSocket)
	Local $arClients = _storageS_Read($hSocket, '_netcode_RouterIncomingSockets')
	Local $nArSize = UBound($arClients)
	ReDim $arClients[$nArSize + 1]
	$arClients[$nArSize] = $hIncomingSocket

	_storageS_Overwrite($hSocket, '_netcode_RouterIncomingSockets', $arClients)
EndFunc

Func __netcode_RouterRemoveIncomingSocket(Const $hSocket, Const $hIncomingSocket)
	Local $arClients = _storageS_Read($hSocket, '_netcode_RouterIncomingSockets')
	Local $nArSize = UBound($arClients)

	if $nArSize = 1 Then
		ReDim $arClients[0]
		_storageS_Overwrite($hSocket, '_netcode_RouterIncomingSockets', $arClients)
		Return
	EndIf

	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		if $arClients[$i] = $hIncomingSocket Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next
	if $nIndex = -1 Then Return ; socket not found. what

	$arClients[$nIndex] = $arClients[$nArSize - 1]
	ReDim $arClients[$nArSize - 1]
	Return
EndFunc

Func __netcode_RouterAddServer(Const $hSocket)
	Local $nArSize = UBound($__net_router_arServices)
	ReDim $__net_router_arServices[$nArSize + 1]
	$__net_router_arServices[$nArSize] = $hSocket

	Local $arIdentifiers[0]
	Local $arClients[0][2] ; incoming socket | outgoing socket
	_storageS_Overwrite($hSocket, '_netcode_RouterIdentifiers', $arIdentifiers)
	_storageS_Overwrite($hSocket, '_netcode_RouterClients', $arClients)
	_storageS_Overwrite($hSocket, '_netcode_RouterIncomingSockets', $arIdentifiers) ; incoming sockets
EndFunc

Func __netcode_RouterRemoveServer(Const $hSocket)
	; also needs to disconnect all clients to it
EndFunc

Func __netcode_RouterAddRoute(Const $hSocket, $sIPTo, $nPortTo, $sIdentifier)
	Local $arIdentifierRoute[2] = [$sIPTo,$nPortTo]
	_storageS_Overwrite($hSocket, '_netcode_RouterIdentifierRoute_' & $sIdentifier, $arIdentifierRoute)
EndFunc

Func __netcode_RouterRemoveRoute(Const $hSocket, $sIdentifier)

EndFunc

Func __netcode_RouterGetRoute(Const $hSocket, $sIdentifier)
	Local $arIdentifierRoute = _storageS_Read($hSocket, '_netcode_RouterIdentifierRoute_' & $sIdentifier)
	if Not IsArray($arIdentifierRoute) Then Return SetError(1, 0, False) ; unknown identifier

	Return $arIdentifierRoute
EndFunc