# Templates predefinidos de Pipeline (Kanban de conversas/contatos).
# São apenas um ponto de partida: após a criação o usuário pode renomear,
# recolorir, adicionar, remover e reordenar os estágios livremente.
module PipelineTemplates
  DEFAULT_STAGE_COLOR = '#1F93FF'.freeze

  TEMPLATES = {
    'suporte' => {
      label: 'Suporte',
      stages: [
        { name: 'Novo', color: '#1F93FF' },
        { name: 'Em Atendimento', color: '#F59E0B' },
        { name: 'Aguardando Cliente', color: '#8B5CF6' },
        { name: 'Resolvido', color: '#10B981' },
        { name: 'Fechado', color: '#64748B' }
      ]
    },
    'vendas' => {
      label: 'Vendas',
      stages: [
        { name: 'Lead', color: '#1F93FF' },
        { name: 'Qualificação', color: '#06B6D4' },
        { name: 'Proposta', color: '#F59E0B' },
        { name: 'Negociação', color: '#8B5CF6' },
        { name: 'Ganho/Perdido', color: '#10B981' }
      ]
    },
    'generico' => {
      label: 'Genérico',
      stages: [
        { name: 'Início', color: '#1F93FF' },
        { name: 'Em Progresso', color: '#F59E0B' },
        { name: 'Concluído', color: '#10B981' }
      ]
    }
  }.freeze

  # Estágios usados quando nenhum template (ou "custom") é escolhido.
  CUSTOM_STAGES = [
    { name: 'Início', color: DEFAULT_STAGE_COLOR }
  ].freeze

  def self.keys
    TEMPLATES.keys
  end

  def self.stages_for(template_key)
    TEMPLATES.dig(template_key.to_s, :stages) || CUSTOM_STAGES
  end

  # Payload para a UI montar os cards de seleção de template com preview.
  def self.as_payload
    TEMPLATES.map do |key, template|
      {
        key: key,
        label: template[:label],
        stages: template[:stages]
      }
    end
  end
end
