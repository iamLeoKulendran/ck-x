import { forwardRef, useEffect, useImperativeHandle, useRef } from 'react';
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import { io, type Socket } from 'socket.io-client';
import 'xterm/css/xterm.css';
import type { StatusType } from './DesktopPanel';

// CK-X terminal helper — xterm 5.3.0 + socket.io-client 4.8.x against the
// same webapp /ssh namespace with the same options (polling transport) as
// terminal-service.js. Lives for the lifetime of the exam page.

export interface TerminalPanelHandle {
    resize: () => void;
    fullscreen: () => void;
}

export const TerminalPanel = forwardRef<
    TerminalPanelHandle,
    { visible: boolean; onStatus: (message: string, type: StatusType) => void }
>(function TerminalPanel({ visible, onStatus }, ref) {
    const containerRef = useRef<HTMLDivElement | null>(null);
    const mountRef = useRef<HTMLDivElement | null>(null);
    const terminalRef = useRef<Terminal | null>(null);
    const fitRef = useRef<FitAddon | null>(null);
    const socketRef = useRef<Socket | null>(null);
    const initializedRef = useRef(false);
    const cleanupRef = useRef<(() => void) | null>(null);

    function resize() {
        const fitAddon = fitRef.current;
        const terminal = terminalRef.current;
        if (!fitAddon || !terminal) return;
        setTimeout(() => {
            try {
                fitAddon.fit();
            } catch {
                return;
            }
            const socket = socketRef.current;
            if (socket && socket.connected) {
                socket.emit('resize', { cols: terminal.cols, rows: terminal.rows });
            }
        }, 100);
    }

    useImperativeHandle(ref, () => ({
        resize,
        fullscreen: () => containerRef.current?.requestFullscreen?.().catch(() => {})
    }));

    // Initialize once, on first becoming visible (legacy lazily initialized
    // on the first view toggle).
    useEffect(() => {
        if (!visible || initializedRef.current || !mountRef.current) return;
        initializedRef.current = true;

        const terminal = new Terminal({
            fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', Menlo, monospace",
            fontSize: 18,
            lineHeight: 1.2,
            theme: {
                background: '#1E1E1E',
                foreground: '#F8F8F8',
                cursor: '#A0A0A0',
                selectionBackground: '#363B4E'
            },
            cursorBlink: true,
            scrollback: 10000,
            allowTransparency: true,
            disableStdin: false
        });
        const fitAddon = new FitAddon();
        terminal.loadAddon(fitAddon);
        terminal.open(mountRef.current);
        try {
            fitAddon.fit();
        } catch {
            // jsdom / zero-size container
        }
        terminalRef.current = terminal;
        fitRef.current = fitAddon;

        onStatus('Connecting to terminal...', 'info');
        const socket = io('/ssh', {
            forceNew: true,
            reconnectionAttempts: 1000,
            timeout: 1000,
            transports: ['polling'] // same workaround as legacy terminal-service.js
        });
        socketRef.current = socket;

        socket.on('connect', () => {
            onStatus('Connected to terminal', 'success');
            socket.emit('resize', { cols: terminal.cols, rows: terminal.rows });
        });
        socket.on('disconnect', () => {
            onStatus('Disconnected from terminal. Reconnecting...', 'error');
            terminal.writeln('\r\n\r\n\x1b[1;31m[CONNECTION LOST]\x1b[0m Terminal disconnected.');
            terminal.writeln('\x1b[0;33mAttempting to reconnect...\x1b[0m\r\n');
            setTimeout(() => {
                if (socketRef.current && !socketRef.current.connected) socketRef.current.connect();
            }, 2000);
        });
        socket.on('error', (err: { message?: string }) => {
            console.error('Socket connection error:', err);
            terminal.writeln(`\r\n\x1b[1;31m[ERROR]\x1b[0m ${err?.message || 'connection error'}\r\n`);
            setTimeout(() => {
                if (socketRef.current && !socketRef.current.connected) socketRef.current.connect();
            }, 2000);
        });
        socket.on('data', (data: string) => {
            terminal.write(data);
        });
        terminal.onData((data) => {
            if (socket.connected) {
                socket.emit('data', data);
            } else {
                terminal.write('\r\n\x1b[1;31m[DISCONNECTED]\x1b[0m Cannot send data. Reconnecting...\r\n');
                socket.connect();
            }
        });

        const handleWindowResize = () => resize();
        window.addEventListener('resize', handleWindowResize);
        // Store teardown for unmount only — switching back to the VNC view
        // must NOT dispose the shell (legacy kept scrollback and session).
        cleanupRef.current = () => {
            window.removeEventListener('resize', handleWindowResize);
            socket.disconnect();
            terminal.dispose();
            terminalRef.current = null;
            socketRef.current = null;
            initializedRef.current = false;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [visible]);

    useEffect(() => {
        return () => {
            cleanupRef.current?.();
            cleanupRef.current = null;
        };
    }, []);

    useEffect(() => {
        if (visible) resize();
    }, [visible]);

    return (
        <div
            ref={containerRef}
            className="ssh-terminal-container flex h-full min-h-0 w-full flex-1 flex-col"
            style={{ display: visible ? 'flex' : 'none' }}
        >
            <div id="terminal" ref={mountRef} className="terminal min-h-0 w-full flex-1" />
        </div>
    );
});
