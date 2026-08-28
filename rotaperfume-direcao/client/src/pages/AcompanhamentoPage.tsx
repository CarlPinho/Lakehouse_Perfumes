import {
  useAnalyticsQuery,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  Badge,
  Skeleton,
  Alert,
  AlertTitle,
  AlertDescription,
  Empty,
  EmptyHeader,
  EmptyTitle,
  EmptyDescription,
} from '@databricks/appkit-ui/react';
import { AlertCircle, CheckCircle2, HelpCircle, XCircle, PhoneOff, BarChart3, Info } from 'lucide-react';

export function AcompanhamentoPage() {
  const { data, loading, error } = useAnalyticsQuery('acompanhamento', {});

  const totalNaFila = data?.reduce((acc, row) => acc + Number(row.na_fila), 0) || 0;
  const totalTrabalhados = data?.reduce((acc, row) => acc + Number(row.trabalhados), 0) || 0;
  const totalVendeu = data?.reduce((acc, row) => acc + Number(row.vendeu), 0) || 0;
  const totalVaiPensar = data?.reduce((acc, row) => acc + Number(row.vai_pensar), 0) || 0;
  const totalSemInteresse = data?.reduce((acc, row) => acc + Number(row.sem_interesse), 0) || 0;
  const totalNaoAtendeu = data?.reduce((acc, row) => acc + Number(row.nao_atendeu), 0) || 0;

  const temRetornos = totalTrabalhados > 0;

  // Filtrar e ordenar vendedores com maior volume de contatos
  const topVendedores = data ? [...data].sort((a, b) => Number(b.na_fila) - Number(a.na_fila)).slice(0, 10) : [];
  const maxContatos = topVendedores.length > 0 ? Math.max(...topVendedores.map((v) => Number(v.na_fila))) : 1;

  return (
    <div className="space-y-6 max-w-7xl mx-auto">
      {/* Cabeçalho com Frase no Topo */}
      <div>
        <h2 className="text-2xl font-bold text-foreground tracking-tight">
          Acompanhamento de Ligações
        </h2>
        <div className="mt-1 flex flex-col sm:flex-row sm:items-center sm:gap-4 text-sm text-muted-foreground">
          <p>
            Dos <strong className="text-foreground">{totalNaFila || 200} contatos</strong> da fila semanal,{' '}
            <strong className="text-foreground">{totalTrabalhados} foram trabalhados</strong> e{' '}
            <strong className="text-emerald-600 dark:text-emerald-400">{totalVendeu} viraram pedido</strong>.
          </p>
        </div>
      </div>

      {/* Aviso de Treino Futuro */}
      <Alert className="bg-muted/40 border-muted">
        <Info className="h-4 w-4 text-primary" />
        <AlertTitle className="text-xs font-semibold">
          Ciclo de Feedback Contínuo (O dado que dá a volta)
        </AlertTitle>
        <AlertDescription className="text-xs text-muted-foreground mt-0.5">
          Os registros de ligação nesta tela alimentam diretamente a tabela <strong>gold.retorno_ligacao</strong>, que servirá como rótulo real para as próximas iterações do modelo de Machine Learning.
        </AlertDescription>
      </Alert>

      {/* Resumo Consolidado de Status */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        <Card className="border p-3">
          <div className="text-xs text-muted-foreground font-medium">Na Fila</div>
          <div className="text-xl font-bold text-foreground mt-1">{totalNaFila}</div>
        </Card>
        <Card className="border p-3">
          <div className="text-xs text-muted-foreground font-medium">Trabalhados</div>
          <div className="text-xl font-bold text-foreground mt-1">{totalTrabalhados}</div>
        </Card>
        <Card className="border p-3">
          <div className="text-xs text-emerald-600 font-medium flex items-center gap-1">
            <CheckCircle2 className="h-3.5 w-3.5" /> Vendeu
          </div>
          <div className="text-xl font-bold text-emerald-600 mt-1">{totalVendeu}</div>
        </Card>
        <Card className="border p-3">
          <div className="text-xs text-amber-600 font-medium flex items-center gap-1">
            <HelpCircle className="h-3.5 w-3.5" /> Vai Pensar
          </div>
          <div className="text-xl font-bold text-amber-600 mt-1">{totalVaiPensar}</div>
        </Card>
        <Card className="border p-3">
          <div className="text-xs text-rose-600 font-medium flex items-center gap-1">
            <XCircle className="h-3.5 w-3.5" /> Sem Interesse
          </div>
          <div className="text-xl font-bold text-rose-600 mt-1">{totalSemInteresse}</div>
        </Card>
        <Card className="border p-3">
          <div className="text-xs text-muted-foreground font-medium flex items-center gap-1">
            <PhoneOff className="h-3.5 w-3.5" /> Não Atendeu
          </div>
          <div className="text-xl font-bold text-foreground mt-1">{totalNaoAtendeu}</div>
        </Card>
      </div>

      {/* Gráfico de Barras Visual: Trabalhados e Vendeu por Vendedor */}
      {temRetornos && (
        <Card className="shadow-sm border">
          <CardHeader className="py-4 px-6 border-b bg-muted/20">
            <CardTitle className="text-base font-semibold flex items-center gap-2">
              <BarChart3 className="h-4 w-4 text-primary" />
              Contatos Trabalhados vs Vendas por Vendedor (Top 10 Carteiras)
            </CardTitle>
          </CardHeader>
          <CardContent className="p-6">
            <div className="space-y-4">
              {topVendedores.map((v) => {
                const naFila = Number(v.na_fila);
                const trab = Number(v.trabalhados);
                const vend = Number(v.vendeu);
                const pctVend = trab > 0 ? Math.round((vend / trab) * 100) : 0;


                return (
                  <div key={v.vendedor} className="space-y-1.5">
                    <div className="flex justify-between text-xs font-medium">
                      <span className="text-foreground">{v.vendedor}</span>
                      <span className="text-muted-foreground">
                        {trab} de {naFila} trabalhados • <strong className="text-emerald-600">{vend} vendas</strong> ({pctVend}% conv.)
                      </span>
                    </div>
                    <div className="w-full bg-muted/40 rounded-full h-3 flex overflow-hidden">
                      <div
                        className="bg-emerald-500 h-full transition-all"
                        style={{ width: `${(vend / maxContatos) * 100}%` }}
                        title={`Vendeu: ${vend}`}
                      />
                      <div
                        className="bg-primary/40 h-full transition-all"
                        style={{ width: `${((trab - vend) / maxContatos) * 100}%` }}
                        title={`Outros desfechos: ${trab - vend}`}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Tabela de Vendedores */}
      <Card className="shadow-sm border overflow-hidden">
        <CardHeader className="py-4 px-6 border-b bg-muted/20 flex flex-row items-center justify-between">
          <div>
            <CardTitle className="text-base font-semibold">
              Progresso por Carteira Comercial
            </CardTitle>
            <p className="text-xs text-muted-foreground mt-0.5">
              Volume de contatos alocados e status de retorno por vendedor
            </p>
          </div>
          {data && (
            <Badge variant="secondary" className="font-medium">
              {data.length} vendedores
            </Badge>
          )}
        </CardHeader>
        <CardContent className="p-0">
          {error && (
            <div className="p-6">
              <Alert variant="destructive">
                <AlertCircle className="h-4 w-4" />
                <AlertTitle>Erro ao carregar dados de acompanhamento</AlertTitle>
                <AlertDescription>{error}</AlertDescription>
              </Alert>
            </div>
          )}

          {loading && (
            <div className="p-6 space-y-3">
              {Array.from({ length: 6 }).map((_, idx) => (
                <div key={idx} className="flex items-center gap-4">
                  <Skeleton className="h-4 w-48" />
                  <Skeleton className="h-4 w-16" />
                  <Skeleton className="h-4 w-16" />
                  <Skeleton className="h-4 w-16" />
                  <Skeleton className="h-4 flex-1" />
                </div>
              ))}
            </div>
          )}

          {/* Estado Vazio Educativo */}
          {!loading && !error && (!temRetornos) && (
            <div className="py-12 px-4">
              <Empty>
                <EmptyHeader>
                  <EmptyTitle>Nenhum retorno de ligação registrado ainda</EmptyTitle>
                  <EmptyDescription className="max-w-md mx-auto text-center mt-2">
                    Os números e gráficos de acompanhamento aparecerão automaticamente assim que os vendedores marcarem os feedbacks das ligações na aba <strong>A semana</strong>. Esse histórico se tornará o dado de treino do modelo da semana que vem!
                  </EmptyDescription>
                </EmptyHeader>
              </Empty>
            </div>
          )}

          {/* Tabela de Vendedores com dados */}
          {!loading && !error && data && data.length > 0 && (
            <div className="overflow-x-auto">
              <Table className="table-fixed w-full text-sm">
                <TableHeader className="bg-muted/30">
                  <TableRow>
                    <TableHead className="w-56 font-semibold">Vendedor</TableHead>
                    <TableHead className="w-24 text-center font-semibold">Na Fila</TableHead>
                    <TableHead className="w-28 text-center font-semibold">Trabalhados</TableHead>
                    <TableHead className="w-24 text-center font-semibold text-emerald-600">Vendeu</TableHead>
                    <TableHead className="w-24 text-center font-semibold text-amber-600">Vai Pensar</TableHead>
                    <TableHead className="w-28 text-center font-semibold text-rose-600">Sem Interesse</TableHead>
                    <TableHead className="w-28 text-center font-semibold text-muted-foreground">Não Atendeu</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data.map((row) => {
                    const naFila = Number(row.na_fila);
                    const trabalhados = Number(row.trabalhados);
                    const progressoPct = naFila > 0 ? Math.round((trabalhados / naFila) * 100) : 0;

                    return (
                      <TableRow key={row.vendedor} className="hover:bg-muted/40 transition-colors">
                        <TableCell className="font-medium text-foreground whitespace-normal break-words">
                          {row.vendedor}
                        </TableCell>
                        <TableCell className="text-center font-mono font-semibold">
                          {naFila}
                        </TableCell>
                        <TableCell className="text-center">
                          <span className="font-mono font-medium">
                            {trabalhados} ({progressoPct}%)
                          </span>
                        </TableCell>
                        <TableCell className="text-center font-mono font-medium text-emerald-600">
                          {Number(row.vendeu)}
                        </TableCell>
                        <TableCell className="text-center font-mono font-medium text-amber-600">
                          {Number(row.vai_pensar)}
                        </TableCell>
                        <TableCell className="text-center font-mono font-medium text-rose-600">
                          {Number(row.sem_interesse)}
                        </TableCell>
                        <TableCell className="text-center font-mono font-medium text-muted-foreground">
                          {Number(row.nao_atendeu)}
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
