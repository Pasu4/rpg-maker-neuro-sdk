import { Socket } from 'net';
import { NeuroClient } from 'neuro-game-sdk';

export class RPGMakerServer {
    private _socket: Socket;
    private _neuroClient: NeuroClient;

    constructor(socket: Socket) {
        this._socket = socket;
        // TODO: Make this configurable
        this._neuroClient = new NeuroClient('ws://localhost:8000', 'RPG Maker', () => {
            // TODO
        });
        this._sendCommand('ok');
    }

    dispose() {
        this._neuroClient.disconnect();
    }

    /**
     * Takes a command sent by RPG Maker and dispatches it to the respective handler.
     * 
     * A command has the form `<id>:<data>`, where `<data>` is an arbitrary string understood by the respective
     * handler for the command of type `<id>`.
     * @param command The command sent by RPG Maker.
     */
    handleCommand(command: string) {
        const separatorIndex = command.indexOf(':');
        const [id, data] = separatorIndex !== -1
            ? [command.slice(0, separatorIndex), command.slice(separatorIndex + 1)]
            : [command, ''];
        switch (id) {
            case 'context':
                this.handleContext(data);
                break;
            default:
                console.error('Error: Unknown command received');
                break;
        }
    }

    /**
     * Send a command to the client.
     * @param command The command to send. Must not contain newline characters (`\n`).
     */
    private _sendCommand(command: string) {
        this._socket.write(command + '\n');
    }

    //#region Client -> Server

    handleContext(context: string) {
        this._neuroClient.sendContext(context);
    }

    //#endregion

    //#region Server -> Client

    sendOk() {
        this._sendCommand('ok');
    }

    //#endregion
}
