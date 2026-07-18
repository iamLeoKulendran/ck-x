import { forwardRef } from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
    'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-ckx-sm font-medium transition-colors disabled:pointer-events-none disabled:opacity-55',
    {
        variants: {
            variant: {
                primary:
                    'bg-primary text-white shadow-ckx-sm hover:bg-primary-active active:bg-primary-active',
                secondary:
                    'border border-line-strong bg-surface-raised text-ink hover:border-ink-muted',
                outline:
                    'border border-primary-border text-primary-ink hover:bg-primary-soft',
                ghost: 'text-ink-secondary hover:bg-surface-soft hover:text-ink',
                danger: 'bg-bad-soft text-bad border border-bad hover:brightness-110'
            },
            size: {
                sm: 'h-8 px-3 text-sm',
                md: 'h-10 px-4 text-sm',
                lg: 'h-12 px-8 text-base'
            }
        },
        defaultVariants: {
            variant: 'primary',
            size: 'md'
        }
    }
);

export interface ButtonProps
    extends React.ButtonHTMLAttributes<HTMLButtonElement>,
        VariantProps<typeof buttonVariants> {}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
    ({ className, variant, size, type = 'button', ...props }, ref) => (
        <button ref={ref} type={type} className={cn(buttonVariants({ variant, size }), className)} {...props} />
    )
);
Button.displayName = 'Button';

export { buttonVariants };
