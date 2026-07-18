// Facilitator API helpers. Paths must stay byte-identical to the legacy
// pages (docs/webapp/api-contract.md) — including any historical quirks.

export const API_BASE = '/facilitator/api/v1';

/** Legacy `api()` helper semantics: parse JSON, then throw
 *  `payload.message || payload.error || 'Request failed'` on a non-OK
 *  response, otherwise return `payload.data`. */
export async function apiData<T>(url: string, options?: RequestInit): Promise<T> {
    const response = await fetch(url, options);
    const payload = await response.json();
    if (!response.ok) {
        throw new Error(payload.message || payload.error || 'Request failed');
    }
    return payload.data as T;
}

/** Loose facilitator response shape shared by the mutation flows. */
export interface RawPayload {
    data?: {
        attemptCount?: number;
        packId?: string;
        valid?: boolean;
        errors?: string[];
        [key: string]: unknown;
    };
    message?: string;
    error?: string;
    errors?: string[];
}

/** Raw variant for flows that need the full payload and ok-flag together
 *  (settings restore/reset, pack import) to replicate legacy error text. */
export async function apiRaw(
    url: string,
    options?: RequestInit
): Promise<{ ok: boolean; payload: RawPayload }> {
    const response = await fetch(url, options);
    const payload = (await response.json()) as RawPayload;
    return { ok: response.ok, payload };
}

export function postJson(body: unknown): RequestInit {
    return {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    };
}

export function patchJson(body: unknown): RequestInit {
    return {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
    };
}
