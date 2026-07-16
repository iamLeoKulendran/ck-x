document.addEventListener('DOMContentLoaded', function() {
    const countersElement = document.getElementById('mistakeCounters');
    const retestQueueElement = document.getElementById('retestQueue');
    const categoryFilter = document.getElementById('categoryFilter');
    const resolvedFilter = document.getElementById('resolvedFilter');
    const statusElement = document.getElementById('mistakesStatus');
    const listElement = document.getElementById('mistakesList');
    const currentYear = document.getElementById('currentYear');

    if (currentYear) {
        currentYear.textContent = new Date().getFullYear();
    }

    let categoriesLoaded = false;

    function escapeHtml(value) {
        const div = document.createElement('div');
        div.textContent = value == null ? '' : String(value);
        return div.innerHTML;
    }

    function formatDate(isoString) {
        const date = new Date(isoString);
        return Number.isNaN(date.getTime()) ? String(isoString || '') : date.toLocaleDateString();
    }

    function api(url, options) {
        return fetch(url, options)
            .then(response => response.json().then(payload => ({ ok: response.ok, payload })))
            .then(({ ok, payload }) => {
                if (!ok) {
                    throw new Error(payload.message || payload.error || 'Request failed');
                }
                return payload.data;
            });
    }

    function renderCounters(counts) {
        const cards = [
            { label: 'Captured mistakes', value: counts.total },
            { label: 'Corrections done', value: counts.correctionDone },
            { label: 'Resolved (corrected + retest passed)', value: counts.resolved },
            { label: 'Retests pending', value: counts.pendingRetests }
        ];
        countersElement.innerHTML = cards.map(card => `
            <div class="col-6 col-md-3">
                <div class="card tools-card mb-0"><div class="card-body py-2">
                    <div class="fs-4 fw-bold">${card.value}</div>
                    <div class="text-muted"><small>${card.label}</small></div>
                </div></div>
            </div>`).join('');
    }

    function renderRetestQueue(queue) {
        if (!queue.length) {
            retestQueueElement.innerHTML = '<p class="text-muted mb-0">No retests scheduled. Schedule one from a mistake below.</p>';
            return;
        }
        const today = new Date().toISOString().slice(0, 10);
        retestQueueElement.innerHTML = '<ul class="list-unstyled mb-0">' + queue.map(entry => {
            const due = String(entry.scheduledFor) <= today
                ? '<span class="tools-chip tools-chip--warn">DUE</span>'
                : '<span class="tools-chip tools-chip--muted">SCHEDULED</span>';
            return `<li class="mb-1">${due} ${escapeHtml(entry.scheduledFor)} — ${escapeHtml(entry.summary)}</li>`;
        }).join('') + '</ul>';
    }

    function renderMistake(mistake) {
        const resolvedChip = mistake.resolved
            ? '<span class="tools-chip tools-chip--ok">RESOLVED</span>'
            : '<span class="tools-chip tools-chip--bad">OPEN</span>';

        const correctionChip = {
            none: '<span class="tools-chip tools-chip--muted">CORRECTION: NONE</span>',
            planned: '<span class="tools-chip tools-chip--warn">CORRECTION: PLANNED</span>',
            done: '<span class="tools-chip tools-chip--ok">CORRECTION: DONE</span>'
        }[mistake.correction.status] || '';

        const retests = (mistake.retests || []).map(retest => {
            const chip = retest.result === 'passed'
                ? '<span class="tools-chip tools-chip--ok">PASSED</span>'
                : retest.result === 'failed'
                    ? '<span class="tools-chip tools-chip--bad">FAILED</span>'
                    : '<span class="tools-chip tools-chip--muted">PENDING</span>';
            const actions = retest.result === 'pending'
                ? `<button type="button" class="btn btn-sm btn-outline-success ms-2" data-action="retest-result" data-mistake="${mistake.mistakeId}" data-retest="${retest.retestId}" data-result="passed">Record pass</button>
                   <button type="button" class="btn btn-sm btn-outline-danger ms-1" data-action="retest-result" data-mistake="${mistake.mistakeId}" data-retest="${retest.retestId}" data-result="failed">Record fail</button>`
                : '';
            return `<li class="mb-1">${chip} scheduled ${escapeHtml(retest.scheduledFor)}${actions}</li>`;
        }).join('');

        const sourceLine = [
            mistake.source.labName || mistake.source.labId,
            `Question ${mistake.source.questionId}`,
            mistake.source.certificationCode
        ].filter(Boolean).join(' · ');

        return `
            <section class="card tools-card" data-mistake-card="${mistake.mistakeId}">
                <div class="card-body">
                    <div class="d-flex flex-wrap gap-2 align-items-center mb-2">
                        ${resolvedChip}
                        ${correctionChip}
                        <span class="tools-chip tools-chip--muted">${escapeHtml(mistake.category)}</span>
                        <span class="text-muted ms-auto"><small>captured ${formatDate(mistake.createdAt)}</small></span>
                    </div>
                    <h2 class="h6 mb-1">${escapeHtml(mistake.summary || 'Mistake')}</h2>
                    <p class="text-muted mb-2"><small>${escapeHtml(sourceLine)} · attempt ${escapeHtml(mistake.source.attemptId)}</small></p>
                    ${mistake.rootCauseNote ? `<p class="mb-2"><strong>Root cause:</strong> ${escapeHtml(mistake.rootCauseNote)}</p>` : ''}
                    ${mistake.correction.note ? `<p class="mb-2"><strong>Corrective action:</strong> ${escapeHtml(mistake.correction.note)}</p>` : ''}

                    <div class="d-flex flex-wrap gap-2 mb-2">
                        <input type="text" class="form-control form-control-sm w-auto flex-grow-1" placeholder="Root cause / corrective action note"
                               data-note-input="${mistake.mistakeId}" aria-label="Correction note">
                        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="correction" data-status="planned" data-mistake="${mistake.mistakeId}">Plan correction</button>
                        <button type="button" class="btn btn-sm btn-outline-primary" data-action="correction" data-status="done" data-mistake="${mistake.mistakeId}">Mark correction done</button>
                    </div>

                    <div class="d-flex flex-wrap gap-2 align-items-center mb-2">
                        <label class="mb-0" for="retest-date-${mistake.mistakeId}"><small>Delayed retest date</small></label>
                        <input type="date" class="form-control form-control-sm w-auto" id="retest-date-${mistake.mistakeId}">
                        <button type="button" class="btn btn-sm btn-outline-secondary" data-action="schedule-retest" data-mistake="${mistake.mistakeId}">Schedule retest</button>
                        <button type="button" class="btn btn-sm btn-outline-danger ms-auto" data-action="delete" data-mistake="${mistake.mistakeId}">Delete</button>
                    </div>

                    ${retests ? `<h3 class="h6 mt-3">Retests</h3><ul class="list-unstyled mb-0">${retests}</ul>` : ''}
                </div>
            </section>`;
    }

    function loadMistakes() {
        const params = new URLSearchParams();
        if (categoryFilter.value) params.set('category', categoryFilter.value);
        if (resolvedFilter.value) params.set('resolved', resolvedFilter.value);

        api(`/facilitator/api/v1/mistakes?${params.toString()}`)
            .then(data => {
                statusElement.textContent = '';
                renderCounters(data.counts);
                renderRetestQueue(data.retestQueue);

                if (!categoriesLoaded) {
                    data.categories.forEach(category => {
                        const option = document.createElement('option');
                        option.value = category;
                        option.textContent = category;
                        categoryFilter.appendChild(option);
                    });
                    categoriesLoaded = true;
                }

                listElement.innerHTML = data.mistakes.length
                    ? data.mistakes.map(renderMistake).join('')
                    : '<div class="tools-empty">No mistakes captured yet. After an exam, use "Log mistake for review" on any failed question in the results page.</div>';
            })
            .catch(error => {
                console.error('Failed to load mistakes:', error);
                statusElement.textContent = 'Failed to load mistakes.';
                statusElement.classList.add('text-danger');
            });
    }

    // Event delegation for all card actions
    listElement.addEventListener('click', (event) => {
        const button = event.target.closest('button[data-action]');
        if (!button) {
            return;
        }

        const mistakeId = button.dataset.mistake;
        const action = button.dataset.action;
        button.disabled = true;

        let request;
        if (action === 'correction') {
            const noteInput = document.querySelector(`[data-note-input="${mistakeId}"]`);
            request = api(`/facilitator/api/v1/mistakes/${mistakeId}/correction`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    status: button.dataset.status,
                    note: noteInput && noteInput.value ? noteInput.value : undefined
                })
            });
        } else if (action === 'schedule-retest') {
            const dateInput = document.getElementById(`retest-date-${mistakeId}`);
            request = api(`/facilitator/api/v1/mistakes/${mistakeId}/retests`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ scheduledFor: dateInput && dateInput.value ? dateInput.value : undefined })
            });
        } else if (action === 'retest-result') {
            request = api(`/facilitator/api/v1/mistakes/${mistakeId}/retests/${button.dataset.retest}`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ result: button.dataset.result })
            });
        } else if (action === 'delete') {
            if (!window.confirm('Delete this mistake record? This cannot be undone from the UI.')) {
                button.disabled = false;
                return;
            }
            request = api(`/facilitator/api/v1/mistakes/${mistakeId}`, { method: 'DELETE' });
        } else {
            button.disabled = false;
            return;
        }

        request
            .then(() => loadMistakes())
            .catch(error => {
                console.error('Mistake action failed:', error);
                alert(`Action failed: ${error.message}`);
                button.disabled = false;
            });
    });

    categoryFilter.addEventListener('change', loadMistakes);
    resolvedFilter.addEventListener('change', loadMistakes);

    loadMistakes();
});
