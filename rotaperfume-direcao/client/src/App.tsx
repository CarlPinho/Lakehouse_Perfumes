import { createBrowserRouter, RouterProvider, NavLink, Outlet } from 'react-router';
import { useState, useEffect } from 'react';
import {
  Button,
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  useIsMobile,
} from '@databricks/appkit-ui/react';
import { Menu, Sparkles, Calendar, ListChecks } from 'lucide-react';
import { SemanaPage } from './pages/SemanaPage';
import { PerguntarPage } from './pages/PerguntarPage';
import { AcompanhamentoPage } from './pages/AcompanhamentoPage';

const navLinkClass = ({ isActive }: { isActive: boolean }) =>
  `px-3 py-1.5 rounded-md text-sm font-medium transition-colors inline-flex items-center gap-1.5 ${
    isActive
      ? 'bg-primary text-primary-foreground shadow-sm'
      : 'text-muted-foreground hover:bg-muted hover:text-foreground'
  }`;

const mobileNavLinkClass = ({ isActive }: { isActive: boolean }) =>
  `px-3 py-2 rounded-md text-sm font-medium transition-colors flex items-center gap-2 ${
    isActive
      ? 'bg-primary text-primary-foreground'
      : 'text-muted-foreground hover:bg-muted hover:text-foreground'
  }`;

type NavLinkClassFn = (props: { isActive: boolean }) => string;

function NavLinks({
  className,
  linkClass,
  onClick,
}: {
  className?: string;
  linkClass: NavLinkClassFn;
  onClick?: () => void;
}) {
  return (
    <nav className={className}>
      <NavLink to="/" end className={linkClass} onClick={onClick}>
        <Calendar className="h-4 w-4" />
        A semana
      </NavLink>
      <NavLink to="/perguntar" className={linkClass} onClick={onClick}>
        <Sparkles className="h-4 w-4" />
        Perguntar
      </NavLink>
      <NavLink to="/acompanhamento" className={linkClass} onClick={onClick}>
        <ListChecks className="h-4 w-4" />
        Acompanhamento
      </NavLink>
    </nav>
  );
}

function Layout() {
  const isMobile = useIsMobile();
  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  useEffect(() => {
    if (!isMobile) setMobileNavOpen(false);
  }, [isMobile]);

  return (
    <div className="min-h-screen bg-background flex flex-col antialiased">
      {/* Top Header */}
      <header className="border-b px-4 md:px-8 py-3.5 flex items-center justify-between bg-card sticky top-0 z-40">
        <div className="flex items-center gap-6">
          <div className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full bg-emerald-500 ring-4 ring-emerald-500/20" />
            <h1 className="text-base font-bold text-foreground tracking-tight">
              Rota do Perfume <span className="font-normal text-muted-foreground">· Direção</span>
            </h1>
          </div>

          {/* Desktop nav */}
          <NavLinks className="hidden md:flex items-center gap-1.5" linkClass={navLinkClass} />
        </div>

        {/* Mobile menu toggle */}
        <div className="md:hidden">
          <Sheet open={mobileNavOpen} onOpenChange={setMobileNavOpen}>
            <Button variant="ghost" size="icon" onClick={() => setMobileNavOpen(true)}>
              <Menu className="h-5 w-5" />
              <span className="sr-only">Abrir navegação</span>
            </Button>
            <SheetContent side="left">
              <SheetHeader>
                <SheetTitle className="text-left font-bold">Rota do Perfume</SheetTitle>
              </SheetHeader>
              <NavLinks
                className="flex flex-col gap-1.5 mt-4"
                linkClass={mobileNavLinkClass}
                onClick={() => setMobileNavOpen(false)}
              />
            </SheetContent>
          </Sheet>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 p-4 md:p-8 bg-muted/10">
        <Outlet />
      </main>
    </div>
  );
}

const router = createBrowserRouter([
  {
    element: <Layout />,
    children: [
      { path: '/', element: <SemanaPage /> },
      { path: '/perguntar', element: <PerguntarPage /> },
      { path: '/acompanhamento', element: <AcompanhamentoPage /> },
    ],
  },
]);

export default function App() {
  return <RouterProvider router={router} />;
}
