# Lógica comum do sync bidirecional. Subclasses implementam o pull específico
# do provedor; o push e a aplicação de itens remotos são compartilhados.
#
# Regras (ver plano do módulo):
# - Push: eventos internos sem external_event_id são criados no provedor
#   (mantendo source: internal — a presença do external id indica "espelhado");
#   alterados desde o último sync são atualizados via PATCH.
# - Conflito: vence o updated_at mais recente; sobrescrita integral + log.
# - Cancelamento remoto vira status cancelled local (nunca deleta).
# - Recorrência: sincroniza só o evento-mestre.
class Calendar::BaseSyncService
  # Tolerância para não tratar o eco do nosso próprio push como conflito.
  CONFLICT_TOLERANCE = 5.seconds
  # Janela de eventos internos considerados para push.
  PUSH_WINDOW = 30.days

  def initialize(connection)
    @connection = connection
    @started_at = Time.current
  end

  def perform
    return unless @connection.sync_enabled

    pull
    push
    @connection.update!(last_synced_at: @started_at)
  end

  private

  def pull
    raise NotImplementedError
  end

  def client
    raise NotImplementedError
  end

  def push_payload(event)
    raise NotImplementedError
  end

  def push_create(event)
    raise NotImplementedError
  end

  def push_update(event)
    raise NotImplementedError
  end

  # ---------- push compartilhado ----------

  def push
    push_new_events
    push_changed_events
  end

  def push_new_events
    @connection.pushable_events
               .where(external_event_id: nil)
               .where(status: %i[confirmed tentative])
               .where('end_time > ?', PUSH_WINDOW.ago)
               .find_each do |event|
      external_id = push_create(event)
      # update_column preserva o updated_at — o push não deve "renovar" o evento
      # e vencer conflitos que ele não venceria.
      event.update_column(:external_event_id, external_id) if external_id.present? # rubocop:disable Rails/SkipsModelValidations
    rescue Calendar::ApiError => e
      Rails.logger.error("[CalendarSync] push create falhou event=#{event.id}: #{e.message}")
    end
  end

  def push_changed_events
    since = @connection.last_synced_at || Time.at(0).utc
    @connection.pushable_events
               .where.not(external_event_id: nil)
               .where('updated_at > ?', since)
               .find_each do |event|
      push_update(event)
    rescue Calendar::ApiError => e
      Rails.logger.error("[CalendarSync] push update falhou event=#{event.id}: #{e.message}")
    end
  end

  # ---------- aplicação de item remoto (compartilhada) ----------

  # attrs: hash do EventMapper (inclui :remote_updated e :chatwoot_id).
  def apply_remote_attributes(external_id, attrs, cancelled: false)
    event = find_local_event(external_id, attrs[:chatwoot_id])

    return apply_remote_cancellation(event) if cancelled

    if event.nil?
      create_local_event(external_id, attrs)
    else
      update_local_event(event, external_id, attrs)
    end
  end

  def find_local_event(external_id, chatwoot_id)
    scope = @connection.account.calendar_events
    event = scope.find_by(external_event_id: external_id)
    event ||= scope.find_by(id: chatwoot_id) if chatwoot_id.present?
    event
  end

  def apply_remote_cancellation(event)
    return if event.nil? || event.cancelled?

    event.update!(status: :cancelled)
  end

  def create_local_event(external_id, attrs)
    return if attrs[:start_time].blank? || attrs[:end_time].blank?

    @connection.account.calendar_events.create!(
      user: @connection.user,
      source: @connection.provider,
      external_event_id: external_id,
      **attrs.slice(:title, :description, :location, :start_time, :end_time, :all_day, :timezone, :status, :recurrence_rule)
    )
  end

  def update_local_event(event, external_id, attrs)
    remote_updated = attrs[:remote_updated]
    # Conflito: o lado editado por último vence; se o local é mais novo, ele
    # será empurrado pelo push — não sobrescreve aqui.
    if remote_updated.present? && event.updated_at > remote_updated + CONFLICT_TOLERANCE
      Rails.logger.info("[CalendarSync] conflito event=#{event.id} winner=local")
      return
    end

    event.assign_attributes(attrs.slice(:title, :description, :location, :start_time, :end_time,
                                        :all_day, :timezone, :status, :recurrence_rule))
    event.external_event_id = external_id if event.external_event_id.blank?
    return unless event.changed?

    Rails.logger.info("[CalendarSync] conflito event=#{event.id} winner=remote") if remote_updated.present?
    event.save!
  end
end
