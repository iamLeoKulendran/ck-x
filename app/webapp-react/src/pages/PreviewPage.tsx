import { useState } from 'react';
import {
    Award,
    Clock,
    Inbox,
    ListChecks,
    Lock,
    TerminalSquare,
    TrendingUp
} from 'lucide-react';
import { AppShell } from '@/components/shell/AppShell';
import { Button } from '@/components/ui/button';
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
} from '@/components/ui/card';
import { Chip } from '@/components/ui/chip';
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
    DialogClose
} from '@/components/ui/dialog';
import { EmptyState } from '@/components/ui/empty-state';
import { LoadingState, Skeleton, Spinner } from '@/components/ui/loading';
import { StatTile } from '@/components/ui/stat-tile';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow
} from '@/components/ui/table';
import { useToast } from '@/components/ui/toast';

function Section({ title, children }: { title: string; children: React.ReactNode }) {
    return (
        <section className="mb-10">
            <h2 className="mb-4 text-xl font-bold tracking-tight">{title}</h2>
            {children}
        </section>
    );
}

export function PreviewPage() {
    const { toast } = useToast();
    const [dialogOpen, setDialogOpen] = useState(false);

    return (
        <AppShell>
            <header className="mb-10 text-center">
                <Chip className="mb-4">Design system · Phase 1</Chip>
                <h1 className="text-4xl font-extrabold tracking-tight">
                    CK-X <span className="ckx-gradient-text">React Foundation</span>
                </h1>
                <p className="mx-auto mt-3 max-w-xl text-ink-secondary">
                    Every reusable component of the migration, rendered in the active theme. Flip the
                    toggle in the navbar to check both modes.
                </p>
            </header>

            <Section title="Buttons">
                <div className="flex flex-wrap items-center gap-3">
                    <Button>Primary</Button>
                    <Button variant="secondary">Secondary</Button>
                    <Button variant="outline">Outline</Button>
                    <Button variant="ghost">Ghost</Button>
                    <Button variant="danger">Danger</Button>
                    <Button disabled>Disabled</Button>
                    <Button size="sm">Small</Button>
                    <Button size="lg">Large</Button>
                </div>
            </Section>

            <Section title="Cards">
                <div className="grid gap-4 md:grid-cols-2">
                    <Card>
                        <CardHeader>
                            <CardTitle>Real Exam Environment</CardTitle>
                            <CardDescription>
                                Terminal-driven practice that mirrors the real thing.
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="flex gap-2">
                            <Chip>Terminal</Chip>
                            <Chip>Split View</Chip>
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardTitle>Timed Practice</CardTitle>
                            <CardDescription>Realistic countdown and exam pacing.</CardDescription>
                        </CardHeader>
                        <CardContent className="flex gap-2">
                            <Chip tone="good">Ready</Chip>
                            <Chip tone="warn">Flagged</Chip>
                            <Chip tone="bad">Failed</Chip>
                        </CardContent>
                    </Card>
                </div>
            </Section>

            <Section title="Stat tiles">
                <div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-6">
                    <StatTile icon={Award} value="5" label="Exam Tracks" />
                    <StatTile icon={ListChecks} value="16+" label="Questions per Mock" />
                    <StatTile icon={Clock} value="120" label="Minute Timed Mocks" />
                    <StatTile icon={TerminalSquare} value="1:1" label="Real Exam Terminal" />
                    <StatTile icon={TrendingUp} value="100" label="Marks per Exam" />
                    <StatTile icon={Lock} value="100%" label="Local & Private" />
                </div>
            </Section>

            <Section title="Chips">
                <div className="flex flex-wrap gap-2">
                    <Chip>Primary</Chip>
                    <Chip tone="good">MET</Chip>
                    <Chip tone="warn">FLAGGED</Chip>
                    <Chip tone="bad">NOT MET</Chip>
                    <Chip tone="muted">NO EVIDENCE</Chip>
                </div>
            </Section>

            <Section title="Table">
                <Card>
                    <CardContent className="p-0">
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Attempt</TableHead>
                                    <TableHead>Score</TableHead>
                                    <TableHead>Weak areas</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                <TableRow>
                                    <TableCell className="font-semibold text-ink">
                                        Mock Exam - CKS - 3
                                    </TableCell>
                                    <TableCell>
                                        <Chip tone="bad">0% low</Chip>
                                    </TableCell>
                                    <TableCell>supply chain (12), network policies (11)</TableCell>
                                </TableRow>
                                <TableRow>
                                    <TableCell className="font-semibold text-ink">
                                        Mock Exam - CKS - 2
                                    </TableCell>
                                    <TableCell>
                                        <Chip tone="good">100% high</Chip>
                                    </TableCell>
                                    <TableCell>None</TableCell>
                                </TableRow>
                            </TableBody>
                        </Table>
                    </CardContent>
                </Card>
            </Section>

            <Section title="Dialog">
                <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
                    <DialogTrigger asChild>
                        <Button variant="secondary">Open dialog</Button>
                    </DialogTrigger>
                    <DialogContent>
                        <DialogHeader>
                            <DialogTitle>Select Your Exam</DialogTitle>
                            <DialogDescription>
                                Dialog styling preview — same shape the exam-selection modal will use.
                            </DialogDescription>
                        </DialogHeader>
                        <DialogFooter>
                            <DialogClose asChild>
                                <Button variant="secondary">Cancel</Button>
                            </DialogClose>
                            <Button onClick={() => setDialogOpen(false)}>Start Exam</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </Section>

            <Section title="Toast">
                <div className="flex flex-wrap gap-3">
                    <Button
                        variant="secondary"
                        onClick={() => toast({ title: 'Results refreshed', tone: 'good' })}
                    >
                        Show success toast
                    </Button>
                    <Button
                        variant="secondary"
                        onClick={() =>
                            toast({
                                title: 'Failed to load packs',
                                description: 'Is the facilitator running?',
                                tone: 'bad'
                            })
                        }
                    >
                        Show error toast
                    </Button>
                </div>
            </Section>

            <Section title="Loading">
                <div className="grid gap-4 md:grid-cols-3">
                    <LoadingState message="Loading previous attempts…" />
                    <div className="flex items-center justify-center rounded-ckx border border-line bg-surface p-4">
                        <Spinner />
                    </div>
                    <div className="space-y-2">
                        <Skeleton className="h-4 w-3/4" />
                        <Skeleton className="h-4 w-full" />
                        <Skeleton className="h-4 w-1/2" />
                    </div>
                </div>
            </Section>

            <Section title="Empty state">
                <EmptyState
                    icon={Inbox}
                    title="No previous attempts yet"
                    description="Complete an exam to build your weak-area history."
                    action={<Button>Start Exam</Button>}
                />
            </Section>
        </AppShell>
    );
}
