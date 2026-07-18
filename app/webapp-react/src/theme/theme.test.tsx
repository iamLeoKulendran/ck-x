import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it } from 'vitest';
import { ThemeProvider } from './ThemeProvider';
import { ThemeToggle } from './ThemeToggle';

describe('theme system', () => {
    beforeEach(() => {
        localStorage.clear();
        document.documentElement.setAttribute('data-theme', 'dark');
    });

    it('toggle flips data-theme and persists the choice', async () => {
        const user = userEvent.setup();
        render(
            <ThemeProvider>
                <ThemeToggle />
            </ThemeProvider>
        );

        const button = screen.getByRole('button', { name: /switch to light theme/i });
        await user.click(button);

        expect(document.documentElement.getAttribute('data-theme')).toBe('light');
        expect(localStorage.getItem('ckx-theme')).toBe('light');

        // Icon/label now offers the way back
        await user.click(screen.getByRole('button', { name: /switch to dark theme/i }));
        expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
        expect(localStorage.getItem('ckx-theme')).toBe('dark');
    });

    it('respects a stored theme on mount', () => {
        localStorage.setItem('ckx-theme', 'light');
        render(
            <ThemeProvider>
                <ThemeToggle />
            </ThemeProvider>
        );
        expect(document.documentElement.getAttribute('data-theme')).toBe('light');
    });
});
