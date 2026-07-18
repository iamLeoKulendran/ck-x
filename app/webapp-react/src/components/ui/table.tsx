import { cn } from '@/lib/utils';

export function Table({ className, ...props }: React.TableHTMLAttributes<HTMLTableElement>) {
    return (
        <div className="w-full overflow-x-auto">
            <table className={cn('w-full border-collapse text-left text-sm', className)} {...props} />
        </div>
    );
}

export function TableHeader(props: React.HTMLAttributes<HTMLTableSectionElement>) {
    return <thead {...props} />;
}

export function TableBody(props: React.HTMLAttributes<HTMLTableSectionElement>) {
    return <tbody {...props} />;
}

export function TableRow({ className, ...props }: React.HTMLAttributes<HTMLTableRowElement>) {
    return <tr className={cn('border-b border-line', className)} {...props} />;
}

export function TableHead({ className, ...props }: React.ThHTMLAttributes<HTMLTableCellElement>) {
    return (
        <th
            className={cn(
                'whitespace-nowrap px-3 py-3 text-xs font-semibold uppercase tracking-wider text-ink-secondary',
                className
            )}
            {...props}
        />
    );
}

export function TableCell({ className, ...props }: React.TdHTMLAttributes<HTMLTableCellElement>) {
    return <td className={cn('px-3 py-3 align-top text-ink-secondary', className)} {...props} />;
}
