// Ports of question-service.js content helpers. The task body is
// pack-authored rich text rendered as HTML exactly as the legacy page did;
// MCQ options and action buttons are React components instead.
import type { ApiQuestion } from './exam-api';

export interface ExamQuestion {
    id: string | number;
    content: string;
    title: string;
    originalData: ApiQuestion;
    flagged: boolean;
    answered: boolean;
    selectedOptions: number[];
}

export function processQuestionContent(content: string): string {
    let processedContent = content;
    processedContent = processedContent.replace(/`([^`]+)`/g, (match, text: string) => {
        if (match.match(/<.*>/) || match.includes('class="code"') || match.includes('class="highlight"')) {
            return match;
        }
        return `<span class="inline-code">${text}</span>`;
    });
    processedContent = processedContent.replace(
        /`([^`]+)`/g,
        '<code class="bg-light px-1 rounded">$1</code>'
    );
    processedContent = processedContent.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    processedContent = processedContent.replace(/\*([^*]+)\*/g, '<em>$1</em>');
    processedContent = processedContent.replace(/\n/g, '<br>');
    processedContent = processedContent.replace(/<\/p><p>/g, '</p>\n<p>');
    processedContent = processedContent.replace(/<\/li><li>/g, '</li>\n<li>');
    return processedContent;
}

export function removeEstimatedTime(content: string): string {
    return String(content || '').replace(/^Estimated time:\s*`?\d+`?\s*minutes?\.\s*\n*/i, '');
}

export function getQuestionWeight(question: ExamQuestion, totalMarks: number | null): string {
    const total = Number.isFinite(totalMarks) && (totalMarks as number) > 0 ? (totalMarks as number) : 100;
    const originalData = question.originalData || {};
    const directWeight = Number(originalData.weightage ?? originalData.weight ?? originalData.marks);
    if (Number.isFinite(directWeight) && directWeight > 0) {
        const pct = Math.round((directWeight / total) * 100);
        return `${directWeight} ${directWeight === 1 ? 'mark' : 'marks'} (${pct}%)`;
    }
    const verification = Array.isArray(originalData.verification) ? originalData.verification : [];
    const derivedWeight = verification.reduce((sum, step) => {
        const stepWeight = Number(step.weightage ?? step.weight ?? 0);
        return Number.isFinite(stepWeight) ? sum + stepWeight : sum;
    }, 0);
    if (derivedWeight > 0) {
        const pct = Math.round((derivedWeight / total) * 100);
        return `${derivedWeight} ${derivedWeight === 1 ? 'mark' : 'marks'} (${pct}%)`;
    }
    return 'Not specified';
}

export function transformQuestionsFromApi(data: { questions?: ApiQuestion[] }): ExamQuestion[] {
    if (data.questions && Array.isArray(data.questions)) {
        return data.questions.map((q) => ({
            id: q.id,
            content: q.question || '',
            title: `Question ${q.id}`,
            originalData: q,
            flagged: false,
            answered: false,
            selectedOptions: []
        }));
    }
    return [];
}

export function isMcqQuestion(question: ExamQuestion): boolean {
    return question.originalData?.type === 'multiple-choice';
}

export function isMultiSelect(question: ExamQuestion): boolean {
    const originalData = question.originalData || {};
    return Array.isArray(originalData.correctOptionIndexes)
        ? originalData.correctOptionIndexes.length > 1
        : Boolean(originalData.multiSelect);
}
