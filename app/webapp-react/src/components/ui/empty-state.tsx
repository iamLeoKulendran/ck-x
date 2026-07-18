import type { LucideIcon } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface EmptyStateProps {
    icon?: LucideIcon;
    title: string;
    description?: string;
    action?: React.ReactNode;
    className?: string;
}

export function EmptyState({ icon: Icon, title, description, action, className }: EmptyStateProps) {
    return (
        <div
            className={cn(
                'flex flex-col items-center gap-2 rounded-ckx border border-dashed border-line-strong',
                'bg-surface-soft p-8 text-center',
                className
            )}
        >
            {Icon ? <Icon aria-hidden className="mb-1 text-ink-muted" size={24} /> : null}
            <div className="font-semibold text-ink">{title}</div>
            {description ? <p className="max-w-md text-sm text-ink-muted">{description}</p> : null}
            {action ? <div className="mt-3">{action}</div> : null}
        </div>
    );
}
