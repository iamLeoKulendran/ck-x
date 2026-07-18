import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { describe, expect, it } from 'vitest';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui/toast';
import { PreviewPage } from './PreviewPage';

function renderPreview() {
    const client = new QueryClient();
    return render(
        <QueryClientProvider client={client}>
            <ThemeProvider>
                <ToastProvider>
                    <MemoryRouter initialEntries={['/react-preview.html']}>
                        <PreviewPage />
                    </MemoryRouter>
                </ToastProvider>
            </ThemeProvider>
        </QueryClientProvider>
    );
}

describe('design-system preview page', () => {
    it('renders every component section', () => {
        renderPreview();
        for (const section of [
            'Buttons',
            'Cards',
            'Stat tiles',
            'Chips',
            'Table',
            'Dialog',
            'Toast',
            'Loading',
            'Empty state'
        ]) {
            expect(screen.getByRole('heading', { name: section })).toBeInTheDocument();
        }
    });

    it('renders inside the app shell with navbar and theme toggle', () => {
        renderPreview();
        expect(screen.getByRole('navigation')).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /switch to (light|dark) theme/i })).toBeInTheDocument();
        expect(screen.getByRole('link', { name: /ck-x/i })).toBeInTheDocument();
    });
});
