// Estilos compartilhados das telas do Service Desk (GLPI).

// Badge de status (cor de fundo + texto) por coluna do Kanban/lista.
export const STATUS_BADGE = {
  aberto: 'bg-slate-100 text-slate-700',
  aguardando_aprovacao: 'bg-yellow-100 text-yellow-700',
  em_execucao: 'bg-woot-100 text-woot-700',
  resolvido: 'bg-green-100 text-green-700',
  violou_sla: 'bg-red-100 text-red-700',
};

// Cor (hex) da coluna do Kanban por status — paleta vibrante (igual à Central).
export const KANBAN_COLOR = {
  aberto: '#5B7FDE',
  aguardando_aprovacao: '#FFB454',
  em_execucao: '#00D9C0',
  resolvido: '#3ddc97',
  violou_sla: '#ff6b81',
};

// Cor do texto por rótulo de prioridade.
export const PRIO_COLOR = {
  Baixa: 'text-slate-500',
  Média: 'text-yellow-600',
  Alta: 'text-yellow-700',
  Crítica: 'text-red-600',
};

// Cor da barra de SLA conforme o percentual restante.
export function slaBarColor(pct) {
  if (pct == null) return 'bg-slate-300';
  if (pct <= 20) return 'bg-red-500';
  if (pct <= 50) return 'bg-yellow-500';
  return 'bg-woot-500';
}

export const PERIOD_OPTIONS = [
  { value: '7d', label: 'Últimos 7 dias' },
  { value: '30d', label: 'Últimos 30 dias' },
  { value: '90d', label: 'Últimos 90 dias' },
  { value: '180d', label: 'Últimos 180 dias' },
];
