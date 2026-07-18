/// <reference lib="dom" />
import '@testing-library/jest-dom/vitest';

// jsdom's File/Blob lacks .text(); the pages use it exactly like the
// legacy JS did, so polyfill it for tests only.
if (typeof Blob !== 'undefined' && !Blob.prototype.text) {
    Blob.prototype.text = function text(this: Blob): Promise<string> {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(String(reader.result));
            reader.onerror = () => reject(reader.error);
            reader.readAsText(this);
        });
    };
}
