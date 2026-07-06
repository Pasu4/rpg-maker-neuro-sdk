# RPG Maker VX Ace Neuro Integration

Neuro integration for RPG Maker VX Ace.
Very WIP.

## How to use

The integration comes in two parts: Ruby scripts for RPG Maker and a proxy server that allows it to talk to the Neuro API.

To install the scripts into your game, open the script editor (F11), create scripts below `( Insert here )` and paste the content of the Ruby files there.
The order should be `RubyLibraryCode.rb`, `JSON.rb`, `NeuroSDK.rb`.
To connect to the Neuro API, add a script command containing `NeuroSDK.connect` to an event.
Note that the proxy server must be started at this point, otherwise the connection will fail.

For the proxy server, run the JavaScript file using `node proxy-server.js`.
I'll build and release this as a standalone executable at some point.

All the main functionality of the API specification is implemented.
Additionally, Neuro will get context from dialogue boxes and can choose dialogue options.
The following is also planned in the future:
- Signifying the speaker in messages
- Equipping weapons/armor/etc.
- Using items from the inventory
- Buying/selling stuff at shops
- Fighting battles
- Walking / pathing to points of interest on the map

## Technical information

Since RPG Maker scripts cannot use packages, the SDK connects to the proxy server via a TCP socket.
However, since not even the standard library is included, the code for the socket has been included in `RubyLibraryCode.rb`.
I got this code from [a WordPress article](https://lthzelda.wordpress.com/2010/04/28/rm-4-tcp-sockets-in-rpg-maker-vx/), but apparently nobody knows where it actually came from (the links to the source are dead as well).

The SDK runs in a loop, constantly checking if there are new messages on the socket.
Since the buffer is continuous, messages are delimited by newline characters.
