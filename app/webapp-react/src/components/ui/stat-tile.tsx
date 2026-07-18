import type { LucideIcon } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface StatTileProps {
    icon: LucideIcon;
    value: string;
    label: string;
    className?: string;
}

export function StatTile({ icon: Icon, value, label, className }: StatTileProps) {
    return (
        <div
            className={cn(
                'rounded-ckx-lg border border-line bg-surface px-3 py-5 text-center shadow-ckx-sm',
                'transition-transform hover:-translate-y-0.5 hover:border-primary-border',
                className
            )}
        >
            <Icon aria-hidden className="mx-auto mb-2 text-primary-ink" size={20} />
            <div className="text-2xl font-bold tracking-tight text-primary-ink">{value}</div>
            <div className="mt-1 text-sm text-ink-secondary">{label}</div>
        </div>
    );
}
