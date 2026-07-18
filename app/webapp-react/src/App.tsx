import { Suspense, lazy } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui/toast';
import { LoadingState } from '@/components/ui/loading';
import { PreviewPage } from '@/pages/PreviewPage';

// Every migrated page is code-split into its own route chunk; analytics
// additionally pulls its chart code only when visited.
const SettingsPage = lazy(() =>
    import('@/pages/SettingsPage').then((module) => ({ default: module.SettingsPage }))
);
const PacksPage = lazy(() =>
    import('@/pages/PacksPage').then((module) => ({ default: module.PacksPage }))
);
const MistakesPage = lazy(() =>
    import('@/pages/MistakesPage').then((module) => ({ default: module.MistakesPage }))
);
const AnalyticsPage = lazy(() => import('@/pages/AnalyticsPage'));

const queryClient = new QueryClient({
    defaultOptions: {
        queries: {
            retry: 1,
            refetchOnWindowFocus: false
        }
    }
});

export function App() {
    return (
        <QueryClientProvider client={queryClient}>
            <ThemeProvider>
                <ToastProvider>
                    <BrowserRouter>
                        <Suspense fallback={<LoadingState />}>
                            <Routes>
                                <Route path="/react-preview.html" element={<PreviewPage />} />
                                <Route path="/settings.html" element={<SettingsPage />} />
                                <Route path="/packs.html" element={<PacksPage />} />
                                <Route path="/mistakes.html" element={<MistakesPage />} />
                                <Route path="/analytics.html" element={<AnalyticsPage />} />
                                {/* Only migrated routes exist here; anything else goes to the preview
                                    so a stray deep link never renders a blank page. */}
                                <Route path="*" element={<Navigate to="/react-preview.html" replace />} />
                            </Routes>
                        </Suspense>
                    </BrowserRouter>
                </ToastProvider>
            </ThemeProvider>
        </QueryClientProvider>
    );
}
