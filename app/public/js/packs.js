document.addEventListener('DOMContentLoaded', function() {
    const packsStatus = document.getElementById('packsStatus');
    const packsTable = document.getElementById('packsTable');
    const packsTableBody = document.getElementById('packsTableBody');
    const importFileInput = document.getElementById('importFileInput');
    const importBtn = document.getElementById('importBtn');
    const importStatus = document.getElementById('importStatus');
    const importErrors = document.getElementById('importErrors');
    const builderQuestions = document.getElementById('builderQuestions');
    const addQuestionBtn = document.getElementById('addQuestionBtn');
    const builderWeightNote = document.getElementById('builderWeightNote');
    const builderValidateBtn = document.getElementById('builderValidateBtn');
    const builderImportBtn = document.getElementById('builderImportBtn');
    const builderDownloadBtn = document.getElementById('builderDownloadBtn');
    const builderStatus = document.getElementById('builderStatus');
    const builderErrors = document.getElementById('builderErrors');
    const currentYear = document.getElementById('currentYear');

    if (currentYear) {
        currentYear.textContent = new Date().getFullYear();
    }

    function escapeHtml(value) {
        const div = document.createElement('div');
        div.textContent = value == null ? '' : String(value);
        return div.innerHTML;
    }

    function setStatus(element, message, isError) {
        element.textContent = message;
        element.classList.toggle('text-danger', Boolean(isError));
        element.classList.toggle('text-success', !isError && Boolean(message));
    }

    function showErrors(listElement, errors) {
        listElement.innerHTML = (errors || []).map(error => `<li>${escapeHtml(error)}</li>`).join('');
    }

    // ---------- Pack list ----------

    function loadPacks() {
        fetch('/facilitator/api/v1/packs')
            .then(response => response.json())
            .then(payload => {
                const packs = payload.data.packs || [];
                packsStatus.textContent = '';
                packsTable.style.display = '';
                packsTableBody.innerHTML = packs.map(pack => `
                    <tr>
                        <td><code>${escapeHtml(pack.id)}</code></td>
                        <td>${escapeHtml(pack.name)}</td>
                        <td>${escapeHtml(pack.category)}</td>
                        <td>${pack.examType === 'mcq' ? 'Multiple choice' : 'Performance (lab)'}</td>
                        <td>${pack.questionCount != null ? pack.questionCount : '—'}</td>
                        <td>${pack.imported ? '<span class="tools-chip tools-chip--warn">imported</span>' : '<span class="tools-chip tools-chip--muted">built-in</span>'}</td>
                        <td>
                            <a class="btn btn-sm btn-outline-primary" href="/facilitator/api/v1/packs/${encodeURIComponent(pack.id)}/export" download>Export</a>
                            ${pack.imported ? `<button type="button" class="btn btn-sm btn-outline-danger ms-1" data-delete-pack="${escapeHtml(pack.id)}">Delete</button>` : ''}
                        </td>
                    </tr>`).join('');
            })
            .catch(error => {
                console.error('Failed to load packs:', error);
                setStatus(packsStatus, 'Failed to load packs.', true);
            });
    }

    packsTableBody.addEventListener('click', (event) => {
        const button = event.target.closest('button[data-delete-pack]');
        if (!button) {
            return;
        }
        const packId = button.dataset.deletePack;
        if (!window.confirm(`Delete imported pack "${packId}" and its files? This cannot be undone from the UI.`)) {
            return;
        }
        fetch(`/facilitator/api/v1/packs/${encodeURIComponent(packId)}`, { method: 'DELETE' })
            .then(response => response.json())
            .then(() => loadPacks())
            .catch(error => alert(`Delete failed: ${error.message}`));
    });

    // ---------- Import ----------

    importFileInput.addEventListener('change', () => {
        importBtn.disabled = !importFileInput.files.length;
        setStatus(importStatus, '', false);
        showErrors(importErrors, []);
    });

    importBtn.addEventListener('click', () => {
        const file = importFileInput.files[0];
        if (!file) {
            return;
        }

        importBtn.disabled = true;
        setStatus(importStatus, 'Validating…', false);
        showErrors(importErrors, []);

        file.text()
            .then(text => {
                let bundle;
                try {
                    bundle = JSON.parse(text);
                } catch (error) {
                    throw new Error('The selected file is not valid JSON');
                }

                const isPerformance = !bundle.config || bundle.config.examType !== 'mcq';
                if (isPerformance) {
                    const confirmed = window.confirm(
                        'This is a PERFORMANCE pack: its shell scripts will execute inside the CK-X exam sandbox ' +
                        '(jumphost and practice cluster) whenever this lab runs.\n\n' +
                        'Only continue if you trust the pack author. Import now?'
                    );
                    if (!confirmed) {
                        throw new Error('Import cancelled');
                    }
                }

                return fetch('/facilitator/api/v1/packs/import', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(bundle)
                });
            })
            .then(response => response.json().then(payload => ({ ok: response.ok, payload })))
            .then(({ ok, payload }) => {
                if (!ok) {
                    showErrors(importErrors, payload.errors || [payload.message || payload.error]);
                    throw new Error(payload.error || 'Import rejected');
                }
                setStatus(importStatus, `Imported "${payload.data.packId}". It now appears in the lab list on the home page.`, false);
                loadPacks();
            })
            .catch(error => {
                setStatus(importStatus, error.message, true);
            })
            .finally(() => {
                importBtn.disabled = !importFileInput.files.length;
            });
    });

    // ---------- MCQ builder ----------

    let questionCounter = 0;

    function addQuestionRow() {
        questionCounter += 1;
        const index = questionCounter;
        const wrapper = document.createElement('div');
        wrapper.className = 'card tools-card';
        wrapper.dataset.builderQuestion = String(index);
        wrapper.innerHTML = `
            <div class="card-body">
                <div class="d-flex align-items-center mb-2">
                    <h3 class="h6 mb-0">Question</h3>
                    <button type="button" class="btn btn-sm btn-outline-danger ms-auto" data-remove-question>Remove</button>
                </div>
                <textarea class="form-control mb-2" rows="2" data-field="question" placeholder="Question text" aria-label="Question text"></textarea>
                <div class="row g-2 mb-2">
                    <div class="col-md-3">
                        <input type="number" class="form-control" data-field="weightage" placeholder="Weight" min="1" max="100" aria-label="Question weight">
                    </div>
                    <div class="col-md-4">
                        <input type="text" class="form-control" data-field="domain" placeholder="Domain id (optional)" aria-label="Domain id">
                    </div>
                    <div class="col-md-5">
                        <input type="text" class="form-control" data-field="concepts" placeholder="Concepts, comma separated" aria-label="Concepts">
                    </div>
                </div>
                <div data-options>
                    ${[0, 1, 2, 3].map(optionIndex => `
                        <div class="d-flex gap-2 mb-1 align-items-center">
                            <input type="checkbox" data-correct="${optionIndex}" aria-label="Option ${optionIndex + 1} is correct">
                            <input type="text" class="form-control form-control-sm" data-option="${optionIndex}" placeholder="Option ${optionIndex + 1}${optionIndex < 2 ? '' : ' (optional)'}" aria-label="Option ${optionIndex + 1} text">
                        </div>`).join('')}
                </div>
                <small class="text-muted">Tick the checkbox next to every correct option.</small>
                <textarea class="form-control mt-2" rows="2" data-field="explanation" placeholder="Explanation shown after evaluation" aria-label="Explanation"></textarea>
            </div>`;

        wrapper.querySelector('[data-remove-question]').addEventListener('click', () => {
            wrapper.remove();
            updateWeightNote();
        });
        wrapper.addEventListener('input', updateWeightNote);
        builderQuestions.appendChild(wrapper);
        updateWeightNote();
    }

    function updateWeightNote() {
        const weights = Array.from(builderQuestions.querySelectorAll('[data-field="weightage"]'))
            .map(input => Number(input.value) || 0);
        const total = weights.reduce((sum, weight) => sum + weight, 0);
        builderWeightNote.textContent = `Total weight: ${total} / 100`;
        builderWeightNote.classList.toggle('text-danger', total !== 100);
    }

    function collectBuilderBundle() {
        const questions = Array.from(builderQuestions.querySelectorAll('[data-builder-question]')).map((card, index) => {
            const options = [0, 1, 2, 3]
                .map(optionIndex => ({
                    text: card.querySelector(`[data-option="${optionIndex}"]`).value.trim(),
                    correct: card.querySelector(`[data-correct="${optionIndex}"]`).checked
                }))
                .filter(option => option.text.length > 0);

            return {
                id: String(index + 1),
                type: 'multiple-choice',
                domain: card.querySelector('[data-field="domain"]').value.trim() || undefined,
                concepts: card.querySelector('[data-field="concepts"]').value
                    .split(',').map(entry => entry.trim()).filter(Boolean),
                question: card.querySelector('[data-field="question"]').value.trim(),
                options: options.map(option => option.text),
                correctOptionIndexes: options
                    .map((option, optionIndex) => (option.correct ? optionIndex : null))
                    .filter(optionIndex => optionIndex !== null),
                weightage: Number(card.querySelector('[data-field="weightage"]').value) || 0,
                explanation: card.querySelector('[data-field="explanation"]').value.trim()
            };
        });

        const category = document.getElementById('builderCategory').value;
        return {
            packFormatVersion: 1,
            lab: {
                id: document.getElementById('builderPackId').value.trim(),
                name: document.getElementById('builderPackName').value.trim(),
                category,
                description: `Community-authored ${category} multiple-choice pack.`,
                difficulty: 'Medium',
                examDurationInMinutes: Number(document.getElementById('builderDuration').value) || 30,
                certificationCode: category === 'Other' ? undefined : category
            },
            config: {
                examType: 'mcq',
                totalMarks: 100,
                lowScore: 50,
                mediumScore: 75,
                highScore: 90
            },
            assessment: { questions },
            answersMarkdown: '# Answers\n\n' + questions.map(question =>
                `## Question ${question.id}\n**Correct option index(es):** ${question.correctOptionIndexes.join(', ')}\n\n${question.explanation}\n`).join('\n'),
            scripts: { setup: {}, validation: {} }
        };
    }

    function submitBuilderBundle(validateOnly) {
        const bundle = collectBuilderBundle();
        setStatus(builderStatus, validateOnly ? 'Validating…' : 'Saving…', false);
        showErrors(builderErrors, []);

        fetch(`/facilitator/api/v1/packs/import?validateOnly=${validateOnly}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(bundle)
        })
            .then(response => response.json().then(payload => ({ ok: response.ok, payload })))
            .then(({ ok, payload }) => {
                if (validateOnly) {
                    if (payload.data && payload.data.valid) {
                        setStatus(builderStatus, 'Bundle is valid.', false);
                    } else {
                        showErrors(builderErrors, (payload.data && payload.data.errors) || payload.errors || []);
                        setStatus(builderStatus, 'Validation failed.', true);
                    }
                    return;
                }
                if (!ok) {
                    showErrors(builderErrors, payload.errors || []);
                    throw new Error(payload.error || 'Save rejected');
                }
                setStatus(builderStatus, `Pack "${payload.data.packId}" saved. It now appears in the lab list.`, false);
                loadPacks();
            })
            .catch(error => setStatus(builderStatus, error.message, true));
    }

    addQuestionBtn.addEventListener('click', addQuestionRow);
    builderValidateBtn.addEventListener('click', () => submitBuilderBundle(true));
    builderImportBtn.addEventListener('click', () => submitBuilderBundle(false));
    builderDownloadBtn.addEventListener('click', () => {
        const bundle = collectBuilderBundle();
        const blob = new Blob([JSON.stringify(bundle, null, 2)], { type: 'application/json' });
        builderDownloadBtn.href = URL.createObjectURL(blob);
        const packId = bundle.lab.id || 'draft';
        builderDownloadBtn.setAttribute('download', `ckx-pack-${packId}.json`);
    });

    // Start with two empty questions to make the shape obvious
    addQuestionRow();
    addQuestionRow();
    loadPacks();
});
