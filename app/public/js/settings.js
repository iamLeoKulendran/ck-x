document.addEventListener('DOMContentLoaded', function() {
    const infoHistoryFile = document.getElementById('infoHistoryFile');
    const infoHistoryVersion = document.getElementById('infoHistoryVersion');
    const infoAttemptCount = document.getElementById('infoAttemptCount');
    const infoTelemetry = document.getElementById('infoTelemetry');
    const restoreFileInput = document.getElementById('restoreFileInput');
    const restoreBtn = document.getElementById('restoreBtn');
    const restoreStatus = document.getElementById('restoreStatus');
    const resetConfirmInput = document.getElementById('resetConfirmInput');
    const resetBtn = document.getElementById('resetBtn');
    const resetStatus = document.getElementById('resetStatus');
    const currentYear = document.getElementById('currentYear');

    if (currentYear) {
        currentYear.textContent = new Date().getFullYear();
    }

    function setStatus(element, message, isError) {
        element.textContent = message;
        element.classList.toggle('text-danger', Boolean(isError));
        element.classList.toggle('text-success', !isError && Boolean(message));
    }

    function loadDataInfo() {
        fetch('/facilitator/api/v1/data/info')
            .then(response => {
                if (!response.ok) {
                    throw new Error('Status ' + response.status);
                }
                return response.json();
            })
            .then(payload => {
                const info = payload.data || {};
                infoHistoryFile.textContent = info.historyFile || 'Unknown';
                infoHistoryVersion.textContent = info.historyVersion != null ? `v${info.historyVersion}` : 'Unknown';
                infoAttemptCount.textContent = info.attemptCount != null ? String(info.attemptCount) : 'Unknown';
                infoTelemetry.textContent = info.telemetryEnabled
                    ? 'Enabled (TRACK_METRICS=true)'
                    : 'Disabled (local-only, default)';
            })
            .catch(error => {
                console.error('Failed to load data info:', error);
                infoHistoryFile.textContent = 'Unavailable';
                infoHistoryVersion.textContent = 'Unavailable';
                infoAttemptCount.textContent = 'Unavailable';
                infoTelemetry.textContent = 'Unavailable';
            });
    }

    // Restore flow: enable button only when a file is selected
    restoreFileInput.addEventListener('change', () => {
        restoreBtn.disabled = !restoreFileInput.files.length;
        setStatus(restoreStatus, '', false);
    });

    restoreBtn.addEventListener('click', () => {
        const file = restoreFileInput.files[0];
        if (!file) {
            return;
        }

        restoreBtn.disabled = true;
        setStatus(restoreStatus, 'Restoring…', false);

        file.text()
            .then(text => {
                let bundle;
                try {
                    bundle = JSON.parse(text);
                } catch (error) {
                    throw new Error('The selected file is not valid JSON');
                }
                return fetch('/facilitator/api/v1/data/restore', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(bundle)
                });
            })
            .then(response => response.json().then(payload => ({ ok: response.ok, payload })))
            .then(({ ok, payload }) => {
                if (!ok) {
                    throw new Error(payload.message || 'Restore rejected');
                }
                setStatus(restoreStatus, `Restored ${payload.data.attemptCount} attempts. Previous file was backed up.`, false);
                loadDataInfo();
            })
            .catch(error => {
                console.error('Restore failed:', error);
                setStatus(restoreStatus, `Restore failed: ${error.message}`, true);
            })
            .finally(() => {
                restoreBtn.disabled = !restoreFileInput.files.length;
            });
    });

    // Reset flow: require typing RESET
    resetConfirmInput.addEventListener('input', () => {
        resetBtn.disabled = resetConfirmInput.value !== 'RESET';
    });

    resetBtn.addEventListener('click', () => {
        resetBtn.disabled = true;
        setStatus(resetStatus, 'Resetting…', false);

        fetch('/facilitator/api/v1/data/reset', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ confirm: 'RESET' })
        })
            .then(response => response.json().then(payload => ({ ok: response.ok, payload })))
            .then(({ ok, payload }) => {
                if (!ok) {
                    throw new Error(payload.message || 'Reset rejected');
                }
                setStatus(resetStatus, 'Attempt history reset. A backup file was written first.', false);
                resetConfirmInput.value = '';
                loadDataInfo();
            })
            .catch(error => {
                console.error('Reset failed:', error);
                setStatus(resetStatus, `Reset failed: ${error.message}`, true);
                resetBtn.disabled = resetConfirmInput.value !== 'RESET';
            });
    });

    loadDataInfo();
});
