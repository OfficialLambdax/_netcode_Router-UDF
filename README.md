# _netcode_Router-UDF
This is an Addon for the _netcode UDF.

This addon requires _netcode_AddonCore.au3
https://github.com/OfficialLambdax/_netcode_AddonCore-UDF

and _netcode_Core.au3
https://github.com/OfficialLambdax/_netcode_Core-UDF

The same describition of the Core UDF applies to here. This UDF is in its concept phase and alot of things are missing and subject to change.

Similiar to the Proxy, but the routes are preset in the Router. A client has to send a identifier right after connecting to let the Router know which route to take. Compatible with any TCP client and server. Either replicate the identifier or use the compatbility proxy in the examples for non Autoit programs.

Main usage is to tunnel multiple application data streams through a single port. So only a single port must be forwarded and opened to the internet. All services, set in the UDF then can be accessed with the help of the Router UDF.

The Router UDF makes entirly use of non blocking sockets.