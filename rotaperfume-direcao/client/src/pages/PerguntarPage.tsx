import { useEffect, useState } from 'react';
import {
  GenieChat,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Alert,
  AlertTitle,
  AlertDescription,
  Badge,
  Skeleton,
} from '@databricks/appkit-ui/react';
import { Sparkles, User, Info, Code } from 'lucide-react';

export function PerguntarPage() {
  const [userEmail, setUserEmail] = useState<string>('');
  const [loadingUser, setLoadingUser] = useState<boolean>(true);

  useEffect(() => {
    fetch('/api/quem-sou')
      .then((res) => res.json())
      .then((data) => {
        setUserEmail(data.email || 'diretoria@rotaperfume.com.br');
        setLoadingUser(false);
      })
      .catch(() => {
        setUserEmail('diretoria@rotaperfume.com.br');
        setLoadingUser(false);
      });
  }, []);

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {/* Cabeçalho */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-2xl font-bold text-foreground tracking-tight">
              Perguntar à Direção Comercial
            </h2>
            <Badge variant="secondary" className="gap-1 px-2 py-0.5 text-xs">
              <Sparkles className="h-3 w-3 text-primary" />
              AI/BI Genie
            </Badge>
          </div>
          <p className="text-sm text-muted-foreground mt-1">
            Assistente conversacional alimentado pelos modelos e dados governados do Unity Catalog
          </p>
        </div>

        {/* Usuário logado */}
        <div className="flex items-center gap-2 bg-muted/40 border rounded-lg px-3 py-1.5 self-start md:self-auto">
          <User className="h-4 w-4 text-muted-foreground" />
          <span className="text-xs text-muted-foreground">Logado como:</span>
          {loadingUser ? (
            <Skeleton className="h-4 w-28" />
          ) : (
            <span className="text-xs font-mono font-medium text-foreground">
              {userEmail}
            </span>
          )}
        </div>
      </div>

      {/* Aviso Permanente de IA e Código SQL */}
      <Alert className="bg-primary/5 border-primary/20 text-foreground">
        <Info className="h-4 w-4 text-primary" />
        <AlertTitle className="text-sm font-semibold flex items-center gap-2">
          Respostas baseadas em IA com rastreabilidade analítica
        </AlertTitle>
        <AlertDescription className="text-xs text-muted-foreground mt-1 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
          <span>
            Todas as respostas são sintetizadas pelo modelo em linguagem natural utilizando as tabelas governadas de <strong>gold</strong>.
          </span>
          <span className="inline-flex items-center gap-1 font-mono text-primary font-medium text-[11px] bg-primary/10 px-2 py-0.5 rounded">
            <Code className="h-3 w-3" /> Show generated code disponível
          </span>
        </AlertDescription>
      </Alert>

      {/* Container do GenieChat */}
      <Card className="shadow-sm border overflow-hidden">
        <CardHeader className="py-3 px-4 border-b bg-muted/20">
          <CardTitle className="text-sm font-medium flex items-center gap-2 text-muted-foreground">
            <span>Espaço: Rota do Perfume · Direção</span>
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          <div className="h-[min(650px,70vh)] w-full">
            <GenieChat alias="default" />
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
