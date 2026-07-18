/** @type {import('tailwindcss').Config} */
export default {
    darkMode: ['selector', '[data-theme="dark"]'],
    content: ['./index.html', './src/**/*.{ts,tsx}'],
    theme: {
        extend: {
            colors: {
                canvas: 'var(--ckx-canvas)',
                surface: 'var(--ckx-surface)',
                'surface-soft': 'var(--ckx-surface-soft)',
                'surface-raised': 'var(--ckx-surface-raised)',
                ink: 'var(--ckx-ink)',
                'ink-secondary': 'var(--ckx-ink-secondary)',
                'ink-muted': 'var(--ckx-ink-muted)',
                primary: {
                    DEFAULT: 'var(--ckx-primary)',
                    hover: 'var(--ckx-primary-hover)',
                    active: 'var(--ckx-primary-active)',
                    soft: 'var(--ckx-primary-soft)',
                    border: 'var(--ckx-primary-border)',
                    ink: 'var(--ckx-primary-ink)'
                },
                accent: 'var(--ckx-accent)',
                good: { DEFAULT: 'var(--ckx-good)', soft: 'var(--ckx-good-soft)' },
                warn: { DEFAULT: 'var(--ckx-warn)', soft: 'var(--ckx-warn-soft)' },
                bad: { DEFAULT: 'var(--ckx-bad)', soft: 'var(--ckx-bad-soft)' },
                line: 'var(--ckx-border)',
                'line-strong': 'var(--ckx-border-strong)'
            },
            borderRadius: {
                ckx: 'var(--ckx-radius)',
                'ckx-sm': 'var(--ckx-radius-sm)',
                'ckx-lg': 'var(--ckx-radius-lg)'
            },
            boxShadow: {
                ckx: 'var(--ckx-shadow)',
                'ckx-sm': 'var(--ckx-shadow-sm)',
                'ckx-lg': 'var(--ckx-shadow-lg)'
            },
            fontFamily: {
                sans: 'var(--ckx-font)',
                mono: 'var(--ckx-font-mono)'
            }
        }
    },
    plugins: []
};
