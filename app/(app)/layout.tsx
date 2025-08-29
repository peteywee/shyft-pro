'use client';

import * as React from 'react';
import Link from 'next/link';
import { usePathname, useSearchParams, useRouter } from 'next/navigation';
import {
  Bot,
  LayoutGrid,
  LogOut,
  MessageSquare,
  PanelLeft,
  Users,
  Moon,
  Sun,
  History,
  UserPlus,
} from 'lucide-react';
import { useTheme } from 'next-themes';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSub,
  DropdownMenuSubTrigger,
  DropdownMenuSubContent,
  DropdownMenuPortal,
} from '@/components/ui/dropdown-menu';
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';
import { Logo } from '@/components/logo';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Suspense } from 'react';

const allNavItems = [
  { href: '/dashboard', icon: LayoutGrid, label: 'Dashboard', roles: ['Admin', 'Manager', 'Staff'] },
  { href: '/pay-history', icon: History, label: 'Pay History', roles: ['Admin', 'Manager', 'Staff'] },
  { href: '/onboarding', icon: UserPlus, label: 'Add Employee', roles: ['Admin', 'Manager'] },
  { href: '/messaging', icon: MessageSquare, label: 'Messages', roles: ['Admin', 'Manager', 'Staff'] },
  { href: '/schedule-assistant', icon: Bot, label: 'AI Assistant', roles: ['Admin', 'Manager'] },
];

function AppLayoutContent({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const router = useRouter();
  const { setTheme } = useTheme();

  const role = searchParams.get('role') || 'Staff';

  React.useEffect(() => {
    if (!searchParams.has('role')) {
      const newParams = new URLSearchParams(Array.from(searchParams.entries()));
      newParams.set('role', 'Staff');
      router.replace(`${pathname}?${newParams.toString()}`);
    }
  }, [pathname, searchParams, router]);

  const setRole = (newRole: string) => {
    const newParams = new URLSearchParams(Array.from(searchParams.entries()));
    newParams.set('role', newRole);
    router.push(`${pathname}?${newParams.toString()}`);
  };

  const navItems = allNavItems.filter((item) => item.roles.includes(role));

  const createHrefWithRole = (href: string) => {
    const params = new URLSearchParams(searchParams.toString());
    if (!params.has('role')) params.set('role', role);
    return `${href}?${params.toString()}`;
  };

  return (
    <div className="flex min-h-screen w-full flex-col bg-muted/40">
      <aside className="fixed inset-y-0 left-0 z-10 hidden w-14 flex-col border-r bg-background sm:flex">
        <nav className="flex flex-col items-center gap-4 px-2 sm:py-5">
          <Link
            href={createHrefWithRole('/dashboard')}
            className="group flex h-9 w-9 shrink-0 items-center justify-center gap-2 rounded-full bg-primary text-lg font-semibold text-primary-foreground md:h-8 md:w-8 md:text-base"
          >
            <Logo className="h-4 w-4 transition-all group-hover:scale-110" />
            <span className="sr-only">Shyft</span>
          </Link>
          <TooltipProvider>
            {navItems.map(({ href, icon: Icon, label }) => (
              <Tooltip key={href}>
                <TooltipTrigger asChild>
                  <Link
                    href={createHrefWithRole(href)}
                    className={`flex h-9 w-9 items-center justify-center rounded-lg transition-colors md:h-8 md:w-8 ${
                      pathname.startsWith(href)
                        ? 'bg-accent text-accent-foreground'
                        : 'text-muted-foreground hover:text-foreground'
                    }`}
                  >
                    <Icon className="h-5 w-5" />
                    <span className="sr-only">{label}</span>
                  </Link>
                </TooltipTrigger>
                <TooltipContent side="right">{label}</TooltipContent>
              </Tooltip>
            ))}
          </TooltipProvider>
        </nav>
        <nav className="mt-auto flex flex-col items-center gap-4 px-2 sm:py-5">
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Link
                  href="/"
                  className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:text-foreground md:h-8 md:w-8"
                >
                  <LogOut className="h-5 w-5" />
                  <span className="sr-only">Logout</span>
                </Link>
              </TooltipTrigger>
              <TooltipContent side="right">Logout</TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </nav>
      </aside>
      <div className="flex flex-col sm:gap-4 sm:py-4 sm:pl-14">
        <header className="sticky top-0 z-30 flex h-14 items-center gap-4 border-b bg-background px-4 sm:static sm:h-auto sm:border-0 sm:bg-transparent sm:px-6">
          <Sheet>
            <SheetTrigger asChild>
              <Button size="icon" variant="outline" className="sm:hidden">
                <PanelLeft className="h-5 w-5" />
                <span className="sr-only">Toggle Menu</span>
              </Button>
            </SheetTrigger>
            <SheetContent side="left" className="sm:max-w-xs">
              <SheetHeader>
                <SheetTitle>Menu</SheetTitle>
              </SheetHeader>
              <nav className="grid gap-6 text-lg font-medium">
                <Link
                  href={createHrefWithRole('/dashboard')}
                  className="group flex h-10 w-10 shrink-0 items-center justify-center gap-2 rounded-full bg-primary text-lg font-semibold text-primary-foreground md:text-base"
                >
                  <Logo className="h-5 w-5 transition-all group-hover:scale-110" />
                  <span className="sr-only">Shyft</span>
                </Link>
                {navItems.map(({ href, icon: Icon, label }) => (
                  <Link
                    key={href}
                    href={createHrefWithRole(href)}
                    className={`flex items-center gap-4 px-2.5 ${
                      pathname.startsWith(href)
                        ? 'text-foreground'
                        : 'text-muted-foreground hover:text-foreground'
                    }`}
                  >
                    <Icon className="h-5 w-5" />
                    {label}
                  </Link>
                ))}
                <Link
                  href="/"
                  className="flex items-center gap-4 px-2.5 text-muted-foreground hover:text-foreground"
                >
                  <LogOut className="h-5 w-5" />
                  Logout
                </Link>
              </nav>
            </SheetContent>
          </Sheet>
          <div className="relative ml-auto flex-1 md:grow-0" />
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="icon" className="overflow-hidden rounded-full">
                <Avatar>
                  <AvatarImage src="https://placehold.co/32x32.png" alt="@user" />
                  <AvatarFallback>{role === 'Admin' ? 'AD' : role === 'Manager' ? 'MG' : 'ST'}</AvatarFallback>
                </Avatar>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuLabel>My Account</DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuRadioGroup value={role} onValueChange={setRole}>
                <DropdownMenuRadioItem value="Admin">Admin</DropdownMenuRadioItem>
                <DropdownMenuRadioItem value="Manager">Manager</DropdownMenuRadioItem>
                <DropdownMenuRadioItem value="Staff">Staff</DropdownMenuRadioItem>
              </DropdownMenuRadioGroup>
              <DropdownMenuSeparator />
              <DropdownMenuSub>
                <DropdownMenuSubTrigger>
                  <Sun className="h-4 w-4 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
                  <Moon className="absolute h-4 w-4 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
                  <span>Toggle theme</span>
                </DropdownMenuSubTrigger>
                <DropdownMenuPortal>
                  <DropdownMenuSubContent>
                    <DropdownMenuItem onClick={() => setTheme('light')}>Light</DropdownMenuItem>
                    <DropdownMenuItem onClick={() => setTheme('dark')}>Dark</DropdownMenuItem>
                    <DropdownMenuItem onClick={() => setTheme('system')}>System</DropdownMenuItem>
                  </DropdownMenuSubContent>
                </DropdownMenuPortal>
              </DropdownMenuSub>
              <DropdownMenuSeparator />
              <DropdownMenuItem asChild>
                <Link href="/">Logout</Link>
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </header>
        <main className="grid flex-1 items-start gap-4 p-4 sm:px-6 sm:py-0 md:gap-8">
          {children}
        </main>
      </div>
    </div>
  );
}

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return <Suspense fallback={<div>Loading...</div>}><AppLayoutContent>{children}</AppLayoutContent></Suspense>;
}
