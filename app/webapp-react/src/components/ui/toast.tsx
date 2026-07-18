import { createContext, useCallback, useContext, useMemo, useState } from 'react';
import * as ToastPrimitive from '@radix-ui/react-toast';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface ToastMessage {
    id: number;
    title: string;
    description?: string;
    tone?: 'default' | 'good' | 'bad';
}

interface ToastContextValue {
    toast: (message: Omit<ToastMessage, 'id'>) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

export function useToast(): ToastContextValue {
    const ctx = useContext(ToastContext);
    if (!ctx) {
        throw new Error('useToast must be used inside <ToastProvider>');
    }
    return ctx;
}

let nextId = 1;

export function ToastProvider({ children }: { children: React.ReactNode }) {
    const [messages, setMessages] = useState<ToastMessage[]>([]);

    const toast = useCallback((message: Omit<ToastMessage, 'id'>) => {
        setMessages((current) => [...current, { ...message, id: nextId++ }]);
    }, []);

    const dismiss = useCallback((id: number) => {
        setMessages((current) => current.filter((m) => m.id !== id));
    }, []);

    const value = useMemo(() => ({ toast }), [toast]);

    return (
        <ToastContext.Provider value={value}>
            <ToastPrimitive.Provider swipeDirection="right">
                {children}
                {messages.map((message) => (
                    <ToastPrimitive.Root
                        key={message.id}
                        duration={5000}
                        onOpenChange={(open) => {
                            if (!open) dismiss(message.id);
                        }}
                        className={cn(
                            'relative rounded-ckx border bg-surface-raised p-4 text-ink shadow-ckx-lg',
                            message.tone === 'good' && 'border-good',
                            message.tone === 'bad' && 'border-bad',
                            (!message.tone || message.tone === 'default') && 'border-line-strong'
                        )}
                    >
                        <ToastPrimitive.Title className="pr-6 text-sm font-semibold">
                            {message.title}
                        </ToastPrimitive.Title>
                        {message.description ? (
                            <ToastPrimitive.Description className="mt-1 text-sm text-ink-secondary">
                                {message.description}
                            </ToastPrimitive.Description>
                        ) : null}
                        <ToastPrimitive.Close
                            aria-label="Dismiss"
                            className="absolute right-3 top-3 text-ink-muted hover:text-ink"
                        >
                            <X size={14} />
                        </ToastPrimitive.Close>
                    </ToastPrimitive.Root>
                ))}
                <ToastPrimitive.Viewport className="fixed bottom-4 right-4 z-[60] flex w-80 max-w-[calc(100vw-2rem)] flex-col gap-2" />
            </ToastPrimitive.Provider>
        </ToastContext.Provider>
    );
}
