import { useEffect } from 'react';

// Legacy pages each shipped a distinct <title>; the SPA shell must restore
// that per route for tabs and assistive technology.
export function usePageTitle(title: string) {
    useEffect(() => {
        const previous = document.title;
        document.title = title;
        return () => {
            document.title = previous;
        };
    }, [title]);
}
