import { Moon, Sun } from 'lucide-react';
import { useTheme } from './ThemeProvider';
import { cn } from '@/lib/utils';

// Matches the reference site: moon shown while in light mode, sun while in
// dark mode — the icon names the mode you switch to.
export function ThemeToggle({ className }: { className?: string }) {
    const { theme, toggle } = useTheme();
    const next = theme === 'dark' ? 'light' : 'dark';

    return (
        <button
            type="button"
            onClick={toggle}
            aria-label={`Switch to ${next} theme`}
            title={`Switch to ${next} theme`}
            className={cn(
                'inline-flex h-9 w-9 items-center justify-center rounded-full border border-line',
                'text-ink-secondary transition-colors hover:bg-surface-soft hover:text-ink',
                className
            )}
        >
            {theme === 'dark' ? <Sun size={16} /> : <Moon size={16} />}
        </button>
    );
}
