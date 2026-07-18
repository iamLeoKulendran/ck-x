import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider } from '@/theme/ThemeProvider';
import { ToastProvider } from '@/components/ui/toast';
import { PreviewPage } from '@/pages/PreviewPage';

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
                        <Routes>
                            <Route path="/react-preview.html" element={<PreviewPage />} />
                            {/* Only migrated routes exist here; anything else goes to the preview
                                so a stray deep link never renders a blank page. */}
                            <Route path="*" element={<Navigate to="/react-preview.html" replace />} />
                        </Routes>
                    </BrowserRouter>
                </ToastProvider>
            </ThemeProvider>
        </QueryClientProvider>
    );
}
