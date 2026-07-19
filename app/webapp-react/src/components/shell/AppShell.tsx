import { cloneElement, isValidElement, useState } from 'react';
import { Menu, X } from 'lucide-react';
import { ThemeToggle } from '@/theme/ThemeToggle';
import { cn } from '@/lib/utils';

// Legacy pages remain plain HTML during the strangler migration, so the nav
// uses hard links (full page loads), not router <Link>s. Once a page is
// migrated its entry keeps the same href and simply lands on a React route.
const NAV_LINKS = [
    { href: '/', label: 'Home' },
    { href: '/analytics.html', label: 'Analytics' },
    { href: '/mistakes.html', label: 'Mistakes' },
    { href: '/packs.html', label: 'Packs' },
    { href: '/settings.html', label: 'Settings' }
];

export function AppShell({
    children,
    activeHref,
    navExtra
}: {
    children: React.ReactNode;
    activeHref?: string;
    // Page-specific nav item (legacy: the conditional "View Result" link)
    navExtra?: React.ReactNode;
}) {
    // Mobile counterpart of the legacy Bootstrap navbar toggler: below md
    // the links live in a disclosure panel under the nav pill.
    const [menuOpen, setMenuOpen] = useState(false);

    return (
        <div className="flex min-h-screen flex-col">
            <header className="pointer-events-none fixed inset-x-0 top-0 z-40 px-4 pt-3.5">
                <nav
                    aria-label="Main"
                    className={cn(
                        'pointer-events-auto mx-auto max-w-[1140px]',
                        'rounded-[18px] border border-line px-4 py-2 shadow-ckx',
                        'backdrop-blur-xl backdrop-saturate-150'
                    )}
                    style={{ backgroundColor: 'var(--ckx-nav-glass)' }}
                >
                    <div className="flex items-center justify-between gap-4">
                        <a href="/" className="flex items-center gap-2 font-bold tracking-tight text-ink">
                            <img src="/assets/ckx-mark.svg" alt="" className="h-6 w-6 rounded-[7px]" />
                            CK-X
                        </a>
                        <div className="hidden items-center gap-1 md:flex">
                            {NAV_LINKS.map((link) => (
                                <a
                                    key={link.href}
                                    href={link.href}
                                    aria-current={link.href === activeHref ? 'page' : undefined}
                                    className={cn(
                                        'rounded-ckx-sm px-3 py-1.5 text-sm font-medium text-ink-secondary',
                                        'hover:bg-surface-soft hover:text-ink',
                                        link.href === activeHref && 'bg-primary-soft text-primary-ink'
                                    )}
                                >
                                    {link.label}
                                </a>
                            ))}
                            {navExtra}
                        </div>
                        <div className="flex items-center gap-1.5">
                            <ThemeToggle />
                            <button
                                type="button"
                                aria-label="Toggle navigation"
                                aria-expanded={menuOpen}
                                aria-controls="mobile-nav"
                                onClick={() => setMenuOpen((open) => !open)}
                                className={cn(
                                    'inline-flex h-9 w-9 items-center justify-center rounded-ckx-sm md:hidden',
                                    'text-ink-secondary hover:bg-surface-soft hover:text-ink',
                                    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary'
                                )}
                            >
                                {menuOpen ? <X aria-hidden size={18} /> : <Menu aria-hidden size={18} />}
                            </button>
                        </div>
                    </div>
                    {menuOpen ? (
                        <div id="mobile-nav" className="mt-2 flex flex-col gap-1 border-t border-line pt-2 md:hidden">
                            {NAV_LINKS.map((link) => (
                                <a
                                    key={link.href}
                                    href={link.href}
                                    aria-current={link.href === activeHref ? 'page' : undefined}
                                    className={cn(
                                        'rounded-ckx-sm px-3 py-2 text-sm font-medium text-ink-secondary',
                                        'hover:bg-surface-soft hover:text-ink',
                                        link.href === activeHref && 'bg-primary-soft text-primary-ink'
                                    )}
                                >
                                    {link.label}
                                </a>
                            ))}
                            {/* The desktop copy keeps the element id; strip it
                                here so the id stays unique in the document. */}
                            {isValidElement<{ id?: string | undefined }>(navExtra)
                                ? cloneElement(navExtra, { id: undefined })
                                : navExtra}
                        </div>
                    ) : null}
                </nav>
            </header>

            <main className="mx-auto w-full max-w-[1140px] flex-1 px-4 pb-16 pt-28">{children}</main>

            <footer className="border-t border-line py-5 text-sm text-ink-muted">
                <div className="mx-auto flex max-w-[1140px] flex-wrap justify-between gap-2 px-4">
                    <span>CK-X — Local Kubernetes Certification Simulator</span>
                    <span>Local-first · Your data stays on this machine</span>
                </div>
            </footer>
        </div>
    );
}
