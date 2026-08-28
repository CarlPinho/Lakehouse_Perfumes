import { createApp, analytics, genie, server, getExecutionContext } from '@databricks/appkit';
import express from 'express';
import { z } from 'zod';

const retornoSchema = z.object({
  cliente_id: z.coerce.number().int({ message: 'cliente_id deve ser um número inteiro' }),
  vendedor: z.string().min(1, { message: 'vendedor não pode ser vazio' }),
  status: z.enum(['vendeu', 'vai_pensar', 'sem_interesse', 'nao_atendeu'], {
    message: 'status deve ser: vendeu, vai_pensar, sem_interesse ou nao_atendeu',
  }),
  comentario: z.string().max(500, { message: 'comentario deve ter no máximo 500 caracteres' }).optional().default(''),
  referencia: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, { message: 'referencia deve estar no formato aaaa-mm-dd' }),
});

createApp({
  plugins: [
    analytics(),
    genie(),
    server(),
  ],
  cache: {
    enabled: false,
  },
  onPluginsReady(appkit) {
    appkit.server.extend((app) => {
      app.use(express.json());

      // GET /api/quem-sou — Identificação do usuário logado
      app.get('/api/quem-sou', (req, res) => {
        const email =
          (req.headers['x-forwarded-email'] as string) ||
          (req.headers['x-databricks-user-email'] as string) ||
          'diretoria@rotaperfume.com.br';
        res.json({ email });
      });

      // POST /api/retorno — Registro do feedback da ligação com validação Zod
      app.post('/api/retorno', async (req, res) => {
        const parseResult = retornoSchema.safeParse(req.body);
        if (!parseResult.success) {
          return res.status(400).json({
            error: 'Corpo da requisição inválido',
            detalhes: parseResult.error.flatten(),
            valores_permitidos_status: ['vendeu', 'vai_pensar', 'sem_interesse', 'nao_atendeu'],
          });
        }

        const { cliente_id, vendedor, status, comentario, referencia } = parseResult.data;
        const registradoPor =
          (req.headers['x-forwarded-email'] as string) ||
          (req.headers['x-databricks-user-email'] as string) ||
          'carloscold6@gmail.com';

        try {
          const context = getExecutionContext();
          const warehouseId =
            (await context.warehouseId) ||
            process.env.DATABRICKS_WAREHOUSE_ID ||
            '56d370db542b32f1';

          await context.client.statementExecution.executeStatement({
            warehouse_id: warehouseId,
            statement: `INSERT INTO lakehouse_rotaperfume.gold.retorno_ligacao (
              cliente_id,
              vendedor,
              status,
              comentario,
              registrado_em,
              registrado_por,
              _referencia
            ) VALUES (
              :cliente_id,
              :vendedor,
              :status,
              :comentario,
              current_timestamp(),
              :registrado_por,
              CAST(:referencia AS DATE)
            )`,
            parameters: [
              { name: 'cliente_id', value: String(cliente_id), type: 'INT' },
              { name: 'vendedor', value: vendedor },
              { name: 'status', value: status },
              { name: 'comentario', value: comentario || '' },
              { name: 'registrado_por', value: registradoPor },
              { name: 'referencia', value: referencia },
            ],
          });

          return res.status(200).json({
            ok: true,
            mensagem: 'Retorno de ligação registrado com sucesso',
            retorno: {
              cliente_id,
              vendedor,
              status,
              comentario,
              registrado_por: registradoPor,
              referencia,
            },
          });
        } catch (error: any) {
          console.error('Erro ao gravar retorno no warehouse:', error);
          return res.status(500).json({
            error: 'Falha ao gravar retorno no banco de dados',
            detalhe: error?.message || String(error),
          });
        }
      });
    });
  },
}).catch(console.error);
