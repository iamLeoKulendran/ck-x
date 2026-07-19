import { forwardRef, useEffect, useImperativeHandle, useRef } from 'react';
import { getVncInfo } from './exam-api';

// VNC iframe wrapper — same /vnc-proxy/?params URL and retry behavior as
// remote-desktop-service.js. The websocket itself goes through nginx
// /websockify; this component only manages the iframe.

export type StatusType = 'info' | 'success' | 'error';

export interface DesktopPanelHandle {
    reconnect: () => void;
    fullscreen: () => void;
}

function requestFullscreenSafe(element: Element | null) {
    element?.requestFullscreen?.().catch(() => {});
}

export const DesktopPanel = forwardRef<
    DesktopPanelHandle,
    { active: boolean; onStatus: (message: string, type: StatusType) => void }
>(function DesktopPanel({ active, onStatus }, ref) {
    const frameRef = useRef<HTMLIFrameElement | null>(null);
    const retryRef = useRef<ReturnType<typeof setTimeout> | null>(null);
    const unmountedRef = useRef(false);

    async function connect() {
        // A manual reconnect supersedes any pending retry
        if (retryRef.current) {
            clearTimeout(retryRef.current);
            retryRef.current = null;
        }
        onStatus('Connecting to Remote Desktop...', 'info');
        try {
            const data = await getVncInfo();
            if (unmountedRef.current || !frameRef.current) return;
            const params = new URLSearchParams({
                autoconnect: '1',
                reconnect: '1',
                resize: 'scale',
                quality: '6',
                compression: '3',
                show_dot: '0',
                password: data.defaultPassword || ''
            });
            frameRef.current.src = `/vnc-proxy/?${params.toString()}`;
            onStatus('Connected to Session', 'success');
        } catch (error) {
            if (unmountedRef.current) return;
            console.error('Error connecting to Remote Desktop:', error);
            onStatus('Failed to connect to Remote Desktop. Retrying...', 'error');
            retryRef.current = setTimeout(() => void connect(), 5000);
        }
    }

    useImperativeHandle(ref, () => ({
        reconnect: () => {
            onStatus('Reconnecting to Remote Desktop...', 'info');
            void connect();
        },
        fullscreen: () => requestFullscreenSafe(frameRef.current)
    }));

    useEffect(() => {
        unmountedRef.current = false;
        if (active) void connect();
        return () => {
            unmountedRef.current = true;
            if (retryRef.current) clearTimeout(retryRef.current);
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [active]);

    return (
        <iframe
            id="vnc-frame"
            ref={frameRef}
            title="Remote Desktop"
            className="h-full w-full flex-1 border-0 bg-black"
            src="about:blank"
        />
    );
});
