import { cn } from '@/lib/utils';

export function Spinner({ className }: { className?: string }) {
    return (
        <span
            role="status"
            aria-label="Loading"
            className={cn(
                'inline-block h-5 w-5 animate-spin rounded-full border-2 border-line-strong border-t-primary',
                className
            )}
        />
    );
}

export function LoadingState({ message = 'Loading…' }: { message?: string }) {
    return (
        <div className="flex items-center gap-3 rounded-ckx border border-line bg-surface-soft p-4 text-ink-muted">
            <Spinner />
            <span className="text-sm">{message}</span>
        </div>
    );
}

export function Skeleton({ className }: { className?: string }) {
    return <div aria-hidden className={cn('animate-pulse rounded-ckx-sm bg-surface-soft', className)} />;
}
