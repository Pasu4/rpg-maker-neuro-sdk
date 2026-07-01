import net from 'net';
import {} from 'neuro-game-sdk';
import { RPGMakerServer } from './server';

const PORT = 7689;
let isConnected = false;

const server = net.createServer((socket) => {
    if (isConnected) {
        console.warn(`Rejected connection from ${socket.remoteAddress}:${socket.remotePort}. Only one client can be connected at a time.`);
        socket.end();
        return;
    }
    isConnected = true;
    console.log(`Client connected: ${socket.remoteAddress}:${socket.remotePort}`);

    // Setup
    const rpgServer = new RPGMakerServer(socket);
    socket.setEncoding('utf8');
    socket.setTimeout(2000);
    socket.allowHalfOpen = false;

    // Events
    socket.on('data', (data) => {
        if (typeof data !== 'string') {
            console.error('Error: Data was not of type string!');
            return;
        }
        rpgServer.handleCommand(data);
    });
    socket.on('close', () => {
        console.log('Client disconnected.');
        isConnected = false;
        rpgServer.dispose();
    });
    socket.on('error', (erm) => {
        console.error(`Socket error: ${erm.message}`);
        socket.end();
    });
});

server.listen(PORT, '127.0.0.1', () => {
    console.log(`Server listening on port ${PORT}`);
});

server.on('error', (erm) => {
    console.error(`Server error: ${erm.message}`);
});
