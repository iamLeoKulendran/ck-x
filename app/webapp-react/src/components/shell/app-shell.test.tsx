import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { AppShell } from './AppShell';

function renderShell() {
    return render(
        <ThemeProvider>
            <AppShell activeHref="/settings.html">
                <p>content</p>
            </AppShell>
        </ThemeProvider>
    );
}

describe('AppShell navigation', () => {
    it('renders every page link with the active page marked', () => {
        renderShell();
        for (const label of ['Home', 'Analytics', 'Mistakes', 'Packs', 'Settings']) {
            expect(screen.getAllByRole('link', { name: label }).length).toBeGreaterThan(0);
        }
        expect(screen.getByRole('link', { name: 'Settings' })).toHaveAttribute(
            'aria-current',
            'page'
        );
    });

    it('mobile toggle opens an accessible menu with all links (legacy toggler parity)', async () => {
        const user = userEvent.setup();
        renderShell();

        const toggle = screen.getByRole('button', { name: 'Toggle navigation' });
        expect(toggle).toHaveAttribute('aria-expanded', 'false');
        expect(document.getElementById('mobile-nav')).toBeNull();

        await user.click(toggle);
        expect(toggle).toHaveAttribute('aria-expanded', 'true');
        const mobileNav = document.getElementById('mobile-nav')!;
        expect(mobileNav).toBeInTheDocument();
        for (const label of ['Home', 'Analytics', 'Mistakes', 'Packs', 'Settings']) {
            expect(
                Array.from(mobileNav.querySelectorAll('a')).some((a) => a.textContent === label)
            ).toBe(true);
        }

        await user.click(toggle);
        expect(toggle).toHaveAttribute('aria-expanded', 'false');
        expect(document.getElementById('mobile-nav')).toBeNull();
    });
});
