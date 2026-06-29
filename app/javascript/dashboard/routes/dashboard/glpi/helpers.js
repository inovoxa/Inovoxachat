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

// Indicador de validação/aprovação do chamado (ícone + texto + cor).
export const VALIDACAO = {
  aguardando: { label: 'Esperando validação', cls: 'text-yellow-600', icon: '⏳' },
  concedida: { label: 'Concedida', cls: 'text-green-600', icon: '✓' },
  recusada: { label: 'Recusada', cls: 'text-red-600', icon: '✕' },
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

// Ícone (emoji) da ação executada no AD, por ID de categoria GLPI.
// Fallback por palavra-chave da ação quando a categoria é desconhecida.
const AD_ICON_CAT = {
  15: '👤', // Criar usuário
  16: '🔑', // Reset de senha
  17: '♻️', // Reativar usuário
  18: '🚫', // Desativar usuário
  19: '📁', // Acesso a pasta
  20: '📧', // Criar e-mail
  22: '🔀', // Transferência de setor
};
export function adIcon(catId, acao = '') {
  if (AD_ICON_CAT[catId]) return AD_ICON_CAT[catId];
  const a = (acao || '').toLowerCase();
  if (a.includes('senha') || a.includes('reset')) return '🔑';
  if (a.includes('criar') || a.includes('cria')) return '👤';
  if (a.includes('desativ')) return '🚫';
  if (a.includes('reativ')) return '♻️';
  if (a.includes('pasta') || a.includes('acesso')) return '📁';
  if (a.includes('email') || a.includes('e-mail') || a.includes('mail')) return '📧';
  if (a.includes('setor') || a.includes('transf')) return '🔀';
  return '⚙️';
}

// Tempo relativo curto em pt-BR a partir de uma data ISO ("há 5 min", "agora").
export function tempoRelativo(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  const seg = Math.round((Date.now() - d.getTime()) / 1000);
  if (seg < 45) return 'agora';
  if (seg < 90) return 'há 1 min';
  const min = Math.round(seg / 60);
  if (min < 60) return `há ${min} min`;
  const h = Math.round(min / 60);
  if (h < 24) return `há ${h} h`;
  const dias = Math.round(h / 24);
  if (dias < 30) return `há ${dias} d`;
  return d.toLocaleDateString('pt-BR');
}

// Duração legível (segundos → "5 min", "2,3 h", "1,5 d").
export function fmtDuracao(seg) {
  if (seg == null) return '—';
  if (seg < 60) return `${Math.round(seg)} s`;
  const min = seg / 60;
  if (min < 60) return `${Math.round(min)} min`;
  const h = min / 60;
  if (h < 24) return `${h.toFixed(1).replace('.', ',')} h`;
  return `${(h / 24).toFixed(1).replace('.', ',')} d`;
}
