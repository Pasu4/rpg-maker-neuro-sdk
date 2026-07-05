import net from 'net';

let isConnected = false;

const HELP = `\
usage: proxy-server [<TCP address>] [<Neuro API address>]
`;

if (process.argv.length >= 2 && ['help', '-h', '--help'].includes(process.argv[2])) {
    console.log(HELP);
    process.exit(0);
}

const tcpAddr = process.argv.length >= 3 ? process.argv[2] : '127.0.0.1:7689';
const apiAddr = process.argv.length >= 4 ? process.argv[3] : process.env['NEURO_SDK_WS_URL'] ?? 'ws://localhost:8000';

const [tcpHost, tcpPortStr] = tcpAddr.split(':', 2);
const tcpPort = Number.parseInt(tcpPortStr);

const server = net.createServer((gameSocket) => {
    if (isConnected) {
        console.warn(`Rejected connection from ${gameSocket.remoteAddress}:${gameSocket.remotePort}. Only one client can be connected at a time.`);
        gameSocket.end();
        return;
    }
    isConnected = true;
    console.log(`Client connected: ${gameSocket.remoteAddress}:${gameSocket.remotePort}`);

    // Setup
    gameSocket.setEncoding('utf8');
    gameSocket.setTimeout(2000);
    gameSocket.allowHalfOpen = false;

    // Events
    gameSocket.on('data', (data) => {
        if (typeof data !== 'string') {
            console.error('Error: Data was not of type string!');
            return;
        }
        // Reparse data just to be safe
        // TODO: Buffer data?
        apiSocket.send(JSON.stringify(JSON.parse(data)));
    });
    gameSocket.on('close', () => {
        console.log('Client disconnected.');
        isConnected = false;

        console.log('Disconnecting from Neuro API.')
        apiSocket.close();
    });
    gameSocket.on('error', (erm) => {
        console.error(`Socket error: ${erm.message}`);
        gameSocket.end();
    });

    // Connect to Neuro API
    const apiSocket = new WebSocket(apiAddr);

    // Events
    apiSocket.addEventListener('open', (_event) => {
        console.log('Connected to Neuro API.');
        // Send custom proxy/connected command
        gameSocket.write(JSON.stringify({
            command: 'proxy/connected',
        }) + '\n');
    });
    apiSocket.addEventListener('message', (event) => {
        // Reparse data because RPG Maker SDK relies on newlines to delimit commands.
        gameSocket.write(JSON.stringify(JSON.parse(event.data)) + '\n');
    });
    apiSocket.addEventListener('error', (erm) => {
        console.error(`WebSocket error: ${erm}`);
    });
    apiSocket.addEventListener('close', (event) => {
        console.log('WebSocket connection closed:', event.code, event.reason);
        console.log('Closing TCP socket.');
        gameSocket.end();
    });
});

server.listen(tcpPort, tcpHost, () => {
    console.log(`Server listening on ${tcpHost}:${tcpPort}`);
});

server.on('error', (erm) => {
    console.error(`Server error: ${erm.message}`);
});
