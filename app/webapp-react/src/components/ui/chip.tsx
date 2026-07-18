import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const chipVariants = cva(
    'inline-flex items-center gap-1 rounded-full border px-3 py-1 text-xs font-semibold leading-tight',
    {
        variants: {
            tone: {
                primary: 'border-primary-border bg-primary-soft text-primary-ink',
                good: 'border-good bg-good-soft text-good',
                warn: 'border-warn bg-warn-soft text-warn',
                bad: 'border-bad bg-bad-soft text-bad',
                muted: 'border-line-strong bg-surface-soft text-ink-muted'
            }
        },
        defaultVariants: {
            tone: 'primary'
        }
    }
);

export interface ChipProps
    extends React.HTMLAttributes<HTMLSpanElement>,
        VariantProps<typeof chipVariants> {}

export function Chip({ className, tone, ...props }: ChipProps) {
    return <span className={cn(chipVariants({ tone }), className)} {...props} />;
}
