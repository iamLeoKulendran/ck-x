import { useEffect, useRef, useState } from 'react';
import { ArrowLeft } from 'lucide-react';
import { marked } from 'marked';
import hljs from 'highlight.js/lib/common';
import 'highlight.js/styles/github-dark.css';
import { Button } from '@/components/ui/button';
import { API_BASE } from '@/lib/api';
import { getQueryParam, navigate } from '@/lib/navigation';
import { usePageTitle } from '@/lib/use-page-title';

// React port of answers.html + js/answers.js. Same endpoint and error
// strings; marked + highlight.js are bundled (lazy route chunk) instead of
// CDN scripts. The markdown comes from the local facilitator's answers.md,
// matching the legacy page's direct innerHTML rendering.

type PageState =
    | { kind: 'loading' }
    | { kind: 'error'; message: string }
    | { kind: 'ready'; html: string };

export function AnswersPage() {
    usePageTitle('Answers | CK-X');
    const [state, setState] = useState<PageState>({ kind: 'loading' });
    const examIdRef = useRef<string | null>(null);
    const contentRef = useRef<HTMLDivElement | null>(null);

    async function fetchAnswers(examId: string) {
        setState({ kind: 'loading' });
        try {
            const response = await fetch(`${API_BASE}/exams/${examId}/answers`);
            if (response.status === 403) {
                setState({
                    kind: 'error',
                    message:
                        'Solutions are locked. They become available once the exam has been evaluated. Submit your exam and check back here after evaluation is complete.'
                });
                return;
            }
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            const markdownText = await response.text();
            marked.setOptions({ breaks: true, gfm: true });
            const html = await marked.parse(markdownText);
            setState({ kind: 'ready', html });
        } catch (error) {
            console.error('Error fetching answers:', error);
            setState({
                kind: 'error',
                message: `Failed to load answers: ${(error as Error).message}`
            });
        }
    }

    const startedRef = useRef(false);
    useEffect(() => {
        if (startedRef.current) return;
        startedRef.current = true;
        const examId = getQueryParam('id');
        if (!examId) {
            setState({
                kind: 'error',
                message: 'No exam ID provided. Please return to the results page.'
            });
            return;
        }
        examIdRef.current = examId;
        void fetchAnswers(examId);
    }, []);

    // Legacy applied hljs.highlightElement to every rendered code block
    useEffect(() => {
        if (state.kind !== 'ready' || !contentRef.current) return;
        contentRef.current.querySelectorAll('pre code').forEach((block) => {
            hljs.highlightElement(block as HTMLElement);
        });
    }, [state]);

    function goBackToResults() {
        if (examIdRef.current) {
            navigate(`/results.html?id=${examIdRef.current}`);
        } else {
            navigate('/');
        }
    }

    return (
        <div className="mx-auto w-full max-w-[900px] px-4 pb-16 pt-8">
            {state.kind === 'loading' ? (
                <div id="pageLoader" role="status" className="py-20 text-center">
                    <div className="mx-auto mb-4 h-8 w-8 animate-spin rounded-full border-2 border-line-strong border-t-primary" />
                    <p className="text-ink-secondary">Loading exam answers...</p>
                </div>
            ) : null}

            {state.kind === 'error' ? (
                <div id="errorMessage" role="alert" className="py-16 text-center">
                    <p id="errorText" className="mb-4 text-bad">
                        {state.message}
                    </p>
                    <Button
                        id="retryButton"
                        variant="secondary"
                        onClick={() => {
                            if (examIdRef.current) void fetchAnswers(examIdRef.current);
                        }}
                    >
                        Retry
                    </Button>
                </div>
            ) : null}

            {state.kind === 'ready' ? (
                <div id="answersContent">
                    <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
                        <h1 className="text-2xl font-bold tracking-tight">Exam Answers</h1>
                        <Button id="backToResultsBtn" variant="outline" onClick={goBackToResults}>
                            <ArrowLeft aria-hidden size={15} className="mr-1.5" /> Back to Results
                        </Button>
                    </div>
                    <div className="mb-4 rounded-ckx border border-line bg-surface-raised p-3 text-sm text-ink-muted">
                        <p id="examId">Exam ID: {examIdRef.current}</p>
                    </div>
                    <div
                        id="markdownContent"
                        ref={contentRef}
                        className="markdown-content prose-ckx"
                        // Same trust model as the legacy page: answers.md is
                        // local pack content rendered directly.
                        dangerouslySetInnerHTML={{ __html: state.html }}
                    />
                </div>
            ) : null}

            <footer className="mt-12 border-t border-line py-5 text-center text-sm text-ink-muted">
                © {new Date().getFullYear()} CK-X Simulator.
            </footer>
        </div>
    );
}
