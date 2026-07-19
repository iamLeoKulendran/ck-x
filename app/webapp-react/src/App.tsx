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
const HomePage = lazy(() =>
    import('@/pages/HomePage').then((module) => ({ default: module.HomePage }))
);
const ResultsPage = lazy(() =>
    import('@/pages/ResultsPage').then((module) => ({ default: module.ResultsPage }))
);
const AnswersPage = lazy(() =>
    import('@/pages/AnswersPage').then((module) => ({ default: module.AnswersPage }))
);
const ExamPage = lazy(() =>
    import('@/exam/ExamPage').then((module) => ({ default: module.ExamPage }))
);

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
                                <Route path="/" element={<HomePage />} />
                                <Route path="/index.html" element={<HomePage />} />
                                <Route path="/results.html" element={<ResultsPage />} />
                                <Route path="/results" element={<ResultsPage />} />
                                <Route path="/answers.html" element={<AnswersPage />} />
                                {/* Phase 4 preview URL; becomes /exam.html at flip time */}
                                <Route path="/exam-react.html" element={<ExamPage />} />
                                <Route path="/exam.html" element={<ExamPage />} />
                                {/* Only migrated routes exist here; anything else goes home so a
                                    stray deep link never renders a blank page. */}
                                <Route path="*" element={<Navigate to="/" replace />} />
                            </Routes>
                        </Suspense>
                    </BrowserRouter>
                </ToastProvider>
            </ThemeProvider>
        </QueryClientProvider>
    );
}
