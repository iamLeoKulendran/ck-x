// Thin wrappers around window.location / window.open so pages can trigger
// legacy-identical navigation while tests stub this module (jsdom cannot
// perform real navigation).

export function navigate(url: string): void {
    window.location.href = url;
}

export function openInNewTab(url: string): void {
    window.open(url, '_blank');
}

export function getQueryParam(name: string): string | null {
    return new URLSearchParams(window.location.search).get(name);
}
