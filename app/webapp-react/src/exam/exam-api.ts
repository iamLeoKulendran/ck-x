// Exam API — byte-identical to js/components/exam-api.js
// (docs/webapp/api-contract.md). Event tracking swallows failures so it can
// never disrupt a running exam.
import { API_BASE } from '@/lib/api';
import { getQueryParam, navigate } from '@/lib/navigation';

export interface ExamEvents {
    examStartTime?: number | string;
    examEndTime?: number | string;
}

export interface ExamInfo {
    id?: string;
    status?: string;
    info?: {
        id?: string;
        name?: string;
        examDurationInMinutes?: number;
        events?: ExamEvents;
        config?: { examType?: string; totalMarks?: number };
    };
}

export interface ApiQuestion {
    id: string | number;
    question?: string;
    machineHostname?: string;
    namespace?: string;
    concepts?: string[];
    domain?: string;
    type?: string;
    options?: string[];
    correctOptionIndexes?: number[];
    multiSelect?: boolean;
    weightage?: number;
    weight?: number;
    marks?: number;
    verification?: { weightage?: number; weight?: number }[];
}

export function getExamId(): string | null {
    const examId = getQueryParam('id');
    if (!examId) {
        console.error('No exam ID found in URL');
        alert('Error: No exam ID provided. Please return to the dashboard.');
        navigate('/');
    }
    return examId;
}

export async function checkExamStatus(examId: string): Promise<string | null> {
    const response = await fetch(`${API_BASE}/exams/${examId}/status`);
    if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
    const data = (await response.json()) as { status?: string };
    return data.status || null;
}

export async function fetchExamData(
    examId: string
): Promise<{ questions?: ApiQuestion[]; info?: ExamInfo['info'] }> {
    const response = await fetch(`${API_BASE}/exams/${examId}/questions`);
    if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
    return (await response.json()) as { questions?: ApiQuestion[]; info?: ExamInfo['info'] };
}

export async function fetchCurrentExamInfo(): Promise<ExamInfo> {
    const response = await fetch(`${API_BASE}/exams/current`);
    if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
    return (await response.json()) as ExamInfo;
}

export async function evaluateExam(examId: string): Promise<unknown> {
    const response = await fetch(`${API_BASE}/exams/${examId}/evaluate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
    });
    if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
    return response.json();
}

export async function submitMcqAnswers(
    examId: string,
    answers: Record<string, number[]>
): Promise<unknown> {
    const response = await fetch(`${API_BASE}/exams/${examId}/mcq-submit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ answers })
    });
    if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
    return response.json();
}

export async function terminateSession(examId: string): Promise<unknown> {
    const response = await fetch(`${API_BASE}/exams/${examId}/terminate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
    });
    if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
    return response.json();
}

export async function getVncInfo(): Promise<{ defaultPassword?: string }> {
    const response = await fetch('/api/vnc-info');
    return (await response.json()) as { defaultPassword?: string };
}

export async function trackExamEvent(
    examId: string,
    events: Record<string, unknown>
): Promise<unknown> {
    try {
        const response = await fetch(`${API_BASE}/exams/${examId}/events`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ events })
        });
        if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);
        return await response.json();
    } catch (error) {
        console.error('Error tracking exam event:', error);
        // Never disrupt the exam over telemetry
        return undefined;
    }
}
