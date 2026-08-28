import { useState } from 'react';
import {
  useAnalyticsQuery,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
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
  Input,
  Button,
} from '@databricks/appkit-ui/react';
import { sql } from '@databricks/appkit-ui/js';
import {
  Users,
  DollarSign,
  TrendingUp,
  PhoneCall,
  AlertCircle,
  CheckCircle2,
  HelpCircle,
  XCircle,
  PhoneOff,
  Check,
  Loader2,
} from 'lucide-react';

interface FilaContentProps {
  vendedorSelecionado: string;
  onRegistrar: (
    clienteId: number,
    vendedor: string,
    status: 'vendeu' | 'vai_pensar' | 'sem_interesse' | 'nao_atendeu',
    comentario: string,
    referencia: string
  ) => Promise<void>;
  gravandoId: number | null;
  comentarios: Record<number, string>;
  setComentario: (clienteId: number, text: string) => void;
}

function FilaContent({
  vendedorSelecionado,
  onRegistrar,
  gravandoId,
  comentarios,
  setComentario,
}: FilaContentProps) {
  const {
    data: filaData,
    loading: filaLoading,
    error: filaError,
  } = useAnalyticsQuery('fila', {
    vendedor: sql.string(vendedorSelecionado),
  });

  return (
    <Card className="shadow-sm border overflow-hidden">
      <CardHeader className="py-4 px-6 border-b bg-muted/20 flex flex-row items-center justify-between">
        <div>
          <CardTitle className="text-base font-semibold">
            Lista de Clientes Priorizados
          </CardTitle>
          <p className="text-xs text-muted-foreground mt-0.5">
            {vendedorSelecionado === 'Todos'
              ? 'Exibindo todos os 200 clientes da base'
              : `Exibindo contatos de ${vendedorSelecionado}`}
          </p>
        </div>
        {filaData && (
          <Badge variant="secondary" className="font-medium">
            {filaData.length} {filaData.length === 1 ? 'cliente' : 'clientes'}
          </Badge>
        )}
      </CardHeader>
      <CardContent className="p-0">
        {filaError && (
          <div className="p-6">
            <Alert variant="destructive">
              <AlertCircle className="h-4 w-4" />
              <AlertTitle>Erro ao consultar a fila semanal</AlertTitle>
              <AlertDescription>{filaError}</AlertDescription>
            </Alert>
          </div>
        )}

        {filaLoading && (
          <div className="p-6 space-y-4">
            {Array.from({ length: 6 }).map((_, idx) => (
              <div key={idx} className="flex items-center gap-4">
                <Skeleton className="h-4 w-8" />
                <Skeleton className="h-4 w-44" />
                <Skeleton className="h-4 w-28" />
                <Skeleton className="h-4 w-16" />
                <Skeleton className="h-4 flex-1" />
              </div>
            ))}
          </div>
        )}

        {!filaLoading && !filaError && (!filaData || filaData.length === 0) && (
          <div className="py-12 px-4">
            <Empty>
              <EmptyHeader>
                <EmptyTitle>Nenhum cliente na fila</EmptyTitle>
                <EmptyDescription className="max-w-md mx-auto text-center mt-2">
                  A fila dos 200 é global e prioriza os clientes com maior propensão estatística de compra em toda a empresa. O vendedor selecionado não possui contatos na lista desta semana.
                </EmptyDescription>
              </EmptyHeader>
            </Empty>
          </div>
        )}

        {!filaLoading && !filaError && filaData && filaData.length > 0 && (
          <div className="overflow-x-auto">
            <Table className="table-fixed w-full text-sm">
              <TableHeader className="bg-muted/30">
                <TableRow>
                  <TableHead className="w-14 text-center font-semibold">Ordem</TableHead>
                  <TableHead className="w-60 font-semibold">Cliente</TableHead>
                  <TableHead className="w-32 font-semibold">Vendedor</TableHead>
                  <TableHead className="w-20 text-center font-semibold">Chance</TableHead>
                  <TableHead className="w-56 font-semibold">Motivo</TableHead>
                  <TableHead className="w-56 font-semibold">Sugestão</TableHead>
                  <TableHead className="w-80 font-semibold">Como foi a ligação</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filaData.map((item) => {
                  const scorePct = Math.round(Number(item.score) * 100);
                  const ticket = Number(item.ticket_medio || 0);
                  const isGravando = gravandoId === item.cliente_id;
                  const temRetorno = Boolean(item.retorno_status);

                  return (
                    <TableRow
                      key={`${item.vendedor}-${item.ordem}-${item.cliente_id}`}
                      className="hover:bg-muted/40 transition-colors"
                    >
                      {/* Ordem */}
                      <TableCell className="text-center font-mono font-medium text-muted-foreground">
                        #{item.ordem}
                      </TableCell>

                      {/* Cliente */}
                      <TableCell className="whitespace-normal break-words">
                        <div className="font-semibold text-foreground leading-tight">
                          {item.razao_social}
                        </div>
                        <div className="text-xs text-muted-foreground mt-0.5 flex items-center gap-2">
                          <span>{item.cidade}/{item.uf}</span>
                          <span>•</span>
                          <span>R$ {ticket.toLocaleString('pt-BR', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}</span>
                        </div>
                      </TableCell>

                      {/* Vendedor */}
                      <TableCell className="whitespace-normal break-words text-xs font-medium text-foreground">
                        {item.vendedor}
                      </TableCell>

                      {/* Chance */}
                      <TableCell className="text-center">
                        <Badge
                          variant={
                            scorePct >= 70
                              ? 'default'
                              : scorePct >= 40
                              ? 'secondary'
                              : 'outline'
                          }
                          className="font-mono text-xs px-2"
                        >
                          {scorePct}%
                        </Badge>
                      </TableCell>

                      {/* Motivo */}
                      <TableCell className="whitespace-normal break-words text-xs text-foreground/90">
                        {item.motivo}
                      </TableCell>

                      {/* Sugestão */}
                      <TableCell className="whitespace-normal break-words text-xs text-muted-foreground">
                        {item.sugestao}
                      </TableCell>

                      {/* Coluna de Ação: Como foi a ligação */}
                      <TableCell className="whitespace-normal break-words">
                        {temRetorno ? (
                          <div className="space-y-1 py-1">
                            <div className="flex items-center gap-1.5">
                              {item.retorno_status === 'vendeu' && (
                                <Badge className="bg-emerald-600 hover:bg-emerald-700 text-white gap-1 text-xs">
                                  <CheckCircle2 className="h-3 w-3" /> Vendeu
                                </Badge>
                              )}
                              {item.retorno_status === 'vai_pensar' && (
                                <Badge className="bg-amber-500 hover:bg-amber-600 text-white gap-1 text-xs">
                                  <HelpCircle className="h-3 w-3" /> Vai pensar
                                </Badge>
                              )}
                              {item.retorno_status === 'sem_interesse' && (
                                <Badge className="bg-rose-600 hover:bg-rose-700 text-white gap-1 text-xs">
                                  <XCircle className="h-3 w-3" /> Sem interesse
                                </Badge>
                              )}
                              {item.retorno_status === 'nao_atendeu' && (
                                <Badge className="bg-slate-600 hover:bg-slate-700 text-white gap-1 text-xs">
                                  <PhoneOff className="h-3 w-3" /> Não atendeu
                                </Badge>
                              )}
                            </div>
                            {item.retorno_comentario && (
                              <p className="text-xs text-foreground italic mt-1 bg-muted/30 p-1.5 rounded border border-muted/50">
                                "{item.retorno_comentario}"
                              </p>
                            )}
                          </div>
                        ) : (
                          <div className="space-y-2 py-1">
                            {/* Campo de comentário */}
                            <Input
                              type="text"
                              placeholder="Observação da conversa..."
                              className="h-7 text-xs"
                              value={comentarios[item.cliente_id] || ''}
                              onChange={(e) => setComentario(item.cliente_id, e.target.value)}
                              disabled={isGravando}
                            />

                            {/* Os 4 botões de desfecho */}
                            <div className="flex flex-wrap gap-1">
                              <Button
                                size="sm"
                                variant="default"
                                className="h-6 px-2 text-[11px] bg-emerald-600 hover:bg-emerald-700 text-white font-medium"
                                disabled={isGravando}
                                onClick={() =>
                                  onRegistrar(
                                    item.cliente_id,
                                    item.vendedor,
                                    'vendeu',
                                    comentarios[item.cliente_id] || '',
                                    '2026-08-31'
                                  )
                                }
                              >
                                {isGravando ? <Loader2 className="h-3 w-3 animate-spin" /> : 'Vendeu'}
                              </Button>

                              <Button
                                size="sm"
                                variant="secondary"
                                className="h-6 px-2 text-[11px] bg-amber-500 hover:bg-amber-600 text-white font-medium"
                                disabled={isGravando}
                                onClick={() =>
                                  onRegistrar(
                                    item.cliente_id,
                                    item.vendedor,
                                    'vai_pensar',
                                    comentarios[item.cliente_id] || '',
                                    '2026-08-31'
                                  )
                                }
                              >
                                {isGravando ? <Loader2 className="h-3 w-3 animate-spin" /> : 'Vai pensar'}
                              </Button>

                              <Button
                                size="sm"
                                variant="destructive"
                                className="h-6 px-2 text-[11px] bg-rose-600 hover:bg-rose-700 text-white font-medium"
                                disabled={isGravando}
                                onClick={() =>
                                  onRegistrar(
                                    item.cliente_id,
                                    item.vendedor,
                                    'sem_interesse',
                                    comentarios[item.cliente_id] || '',
                                    '2026-08-31'
                                  )
                                }
                              >
                                {isGravando ? <Loader2 className="h-3 w-3 animate-spin" /> : 'Sem interesse'}
                              </Button>

                              <Button
                                size="sm"
                                variant="outline"
                                className="h-6 px-2 text-[11px] bg-slate-100 hover:bg-slate-200 text-slate-700 dark:bg-slate-800 dark:text-slate-300 font-medium"
                                disabled={isGravando}
                                onClick={() =>
                                  onRegistrar(
                                    item.cliente_id,
                                    item.vendedor,
                                    'nao_atendeu',
                                    comentarios[item.cliente_id] || '',
                                    '2026-08-31'
                                  )
                                }
                              >
                                {isGravando ? <Loader2 className="h-3 w-3 animate-spin" /> : 'Não atendeu'}
                              </Button>
                            </div>
                          </div>
                        )}
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
  );
}

export function SemanaPage() {
  const [vendedorSelecionado, setVendedorSelecionado] = useState<string>('Todos');
  const [recargaKey, setRecargaKey] = useState<number>(0);
  const [gravandoId, setGravandoId] = useState<number | null>(null);
  const [comentarios, setComentarios] = useState<Record<number, string>>({});
  const [mensagemSucesso, setMensagemSucesso] = useState<string | null>(null);
  const [mensagemErro, setMensagemErro] = useState<string | null>(null);

  const {
    data: kpisData,
    loading: kpisLoading,
    error: kpisError,
  } = useAnalyticsQuery('kpis_semana', {});

  const { data: vendedoresData } = useAnalyticsQuery('vendedores', {});

  const kpi = kpisData && kpisData.length > 0 ? kpisData[0] : null;

  const handleSetComentario = (clienteId: number, text: string) => {
    setComentarios((prev) => ({ ...prev, [clienteId]: text }));
  };

  const handleRegistrarRetorno = async (
    clienteId: number,
    vendedor: string,
    status: 'vendeu' | 'vai_pensar' | 'sem_interesse' | 'nao_atendeu',
    comentario: string,
    referencia: string
  ) => {
    setGravandoId(clienteId);
    setMensagemErro(null);
    setMensagemSucesso(null);

    try {
      const res = await fetch('/api/retorno', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          cliente_id: clienteId,
          vendedor,
          status,
          comentario,
          referencia,
        }),
      });

      const json = await res.json();

      if (!res.ok) {
        throw new Error(json.error || json.detalhe || 'Erro desconhecido ao registrar feedback');
      }

      // Limpar comentário gravado
      setComentarios((prev) => {
        const copy = { ...prev };
        delete copy[clienteId];
        return copy;
      });

      // Feedback de sucesso
      setMensagemSucesso(`Retorno registrado com sucesso para o cliente #${clienteId}!`);

      // RECARGA: Incrementa key para remontar as consultas sem parâmetro falso no SQL
      setRecargaKey((prev) => prev + 1);

      // Auto-ocultar alerta de sucesso após 5 segundos
      setTimeout(() => setMensagemSucesso(null), 5000);
    } catch (err: any) {
      console.error('Erro na gravação do retorno:', err);
      setMensagemErro(`Falha ao registrar feedback: ${err?.message || String(err)}`);
    } finally {
      setGravandoId(null);
    }
  };

  return (
    <div className="space-y-6 max-w-7xl mx-auto">
      {/* Cabeçalho da Página */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-foreground tracking-tight">
            Fila Priorizada da Semana
          </h2>
          <p className="text-sm text-muted-foreground mt-1">
            Top 200 clientes com maior probabilidade de compra nos próximos 7 dias — Corte de referência: {kpi?.referencia || '2026-08-31'}
          </p>
        </div>

        {/* Filtro por Vendedor */}
        <div className="w-full md:w-72">
          <Select
            value={vendedorSelecionado}
            onValueChange={(val) => setVendedorSelecionado(val)}
          >
            <SelectTrigger id="select-vendedor" className="w-full">
              <SelectValue placeholder="Filtrar por vendedor" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="Todos">Todos os vendedores (200 contatos)</SelectItem>
              {vendedoresData?.map((v) => (
                <SelectItem key={v.vendedor} value={v.vendedor}>
                  {v.vendedor} ({Number(v.contatos)} contatos)
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      {/* Alertas de Notificação */}
      {mensagemSucesso && (
        <Alert className="bg-emerald-500/10 border-emerald-500/30 text-emerald-700 dark:text-emerald-300">
          <Check className="h-4 w-4 text-emerald-600" />
          <AlertTitle className="font-semibold">Sucesso</AlertTitle>
          <AlertDescription className="text-xs">{mensagemSucesso}</AlertDescription>
        </Alert>
      )}

      {mensagemErro && (
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertTitle className="font-semibold">Atenção</AlertTitle>
          <AlertDescription className="text-xs">{mensagemErro}</AlertDescription>
        </Alert>
      )}

      {/* 4 Cartões de KPI no Topo (remontados com recargaKey) */}
      <div key={`kpis-${recargaKey}`} className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Contatos */}
        <Card className="shadow-sm border">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Contatos da Semana
            </CardTitle>
            <Users className="h-4 w-4 text-primary" />
          </CardHeader>
          <CardContent>
            {kpisLoading ? (
              <Skeleton className="h-8 w-24" />
            ) : kpisError ? (
              <div className="text-xs text-destructive">Erro ao carregar</div>
            ) : (
              <div>
                <div className="text-2xl font-bold text-foreground">
                  {Number(kpi?.contatos || 0)}
                </div>
                <p className="text-xs text-muted-foreground mt-1">
                  Entre {Number(kpi?.vendedores || 0)} vendedores ativos
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Card 2: Receita Esperada */}
        <Card className="shadow-sm border">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Receita Esperada
            </CardTitle>
            <DollarSign className="h-4 w-4 text-emerald-600" />
          </CardHeader>
          <CardContent>
            {kpisLoading ? (
              <Skeleton className="h-8 w-32" />
            ) : kpisError ? (
              <div className="text-xs text-destructive">Erro ao carregar</div>
            ) : (
              <div>
                <div className="text-2xl font-bold text-foreground">
                  R$ {Number(kpi?.receita_esperada || 0).toLocaleString('pt-BR', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  })}
                </div>
                <p className="text-xs text-muted-foreground mt-1">
                  Estimativa: SUM(score × ticket médio)
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Card 3: Conversão Prevista */}
        <Card className="shadow-sm border">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Conversão Prevista
            </CardTitle>
            <TrendingUp className="h-4 w-4 text-indigo-600" />
          </CardHeader>
          <CardContent>
            {kpisLoading ? (
              <Skeleton className="h-8 w-28" />
            ) : kpisError ? (
              <div className="text-xs text-destructive">Erro ao carregar</div>
            ) : (
              <div>
                <div className="text-2xl font-bold text-foreground">
                  {(
                    (Number(kpi?.acertos_top200 || 0) /
                      Number(kpi?.contatos || 200)) *
                    100
                  ).toFixed(1)}%
                </div>
                <p className="text-xs text-muted-foreground mt-1">
                  vs {(Number(kpi?.taxa_base || 0) * 100).toFixed(1)}% taxa base ({Number(kpi?.lift_top200 || 0).toFixed(2)}x lift)
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Card 4: Já Trabalhados */}
        <Card className="shadow-sm border">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              Já Trabalhados
            </CardTitle>
            <PhoneCall className="h-4 w-4 text-amber-600" />
          </CardHeader>
          <CardContent>
            {kpisLoading ? (
              <Skeleton className="h-8 w-20" />
            ) : kpisError ? (
              <div className="text-xs text-destructive">Erro ao carregar</div>
            ) : (
              <div>
                <div className="text-2xl font-bold text-foreground">
                  {Number(kpi?.ja_trabalhados || 0)}
                </div>
                <p className="text-xs text-muted-foreground mt-1">
                  {Number(kpi?.viraram_pedido || 0)} viraram pedido
                </p>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Tabela dos 200 Leads remontada pelo recargaKey */}
      <FilaContent
        key={`fila-${recargaKey}`}
        vendedorSelecionado={vendedorSelecionado}
        onRegistrar={handleRegistrarRetorno}
        gravandoId={gravandoId}
        comentarios={comentarios}
        setComentario={handleSetComentario}
      />
    </div>
  );
}
