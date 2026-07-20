json.payload do
  json.array! @pipeline.pipeline_stages do |stage|
    conversations = stage.conversations
                         .where(last_activity_at: @since..)
                         .includes(:assignee, :inbox, contact: { avatar_attachment: :blob })
                         .order(last_activity_at: :desc)
    conversations = conversations.where(inbox_id: @inbox_ids) if @inbox_ids.present?

    contacts = stage.contacts.where(created_at: @since..).order(created_at: :desc)
    if @inbox_ids.present?
      contacts = contacts.where(id: ContactInbox.where(inbox_id: @inbox_ids).select(:contact_id))
    end

    # Próximo evento futuro por conversa (uma consulta por estágio, sem N+1).
    # Nota: recorrentes cujo mestre já passou não aparecem no badge (MVP).
    conversation_ids = conversations.map(&:id)
    next_events_by_conversation = CalendarEvent
                                  .where(conversation_id: conversation_ids, status: %i[confirmed tentative])
                                  .where('start_time > ?', Time.current)
                                  .order(:start_time)
                                  .group_by(&:conversation_id)
                                  .transform_values(&:first)

    json.id stage.id
    json.name stage.name
    json.color stage.color
    json.position stage.position
    json.total_count conversations.size + contacts.size

    json.conversations conversations do |conversation|
      json.id conversation.display_id
      json.status conversation.status
      json.priority conversation.priority
      json.inbox_id conversation.inbox_id
      json.inbox_name conversation.inbox&.name
      json.last_activity_at conversation.last_activity_at.to_i
      json.labels conversation.cached_label_list_array
      last_message = conversation.messages.where(message_type: [0, 1], private: false)
                                 .reorder(created_at: :desc).first
      if last_message
        json.last_message do
          json.content last_message.content.to_s.truncate(90)
          json.created_at last_message.created_at.to_i
          json.incoming last_message.incoming?
        end
      end
      json.contact do
        json.id conversation.contact.id
        json.name conversation.contact.name
        json.thumbnail conversation.contact.avatar_url
      end
      if conversation.assignee
        json.assignee do
          json.id conversation.assignee.id
          json.name conversation.assignee.name
          json.thumbnail conversation.assignee.avatar_url
        end
      end
      next_event = next_events_by_conversation[conversation.id]
      if next_event
        json.next_calendar_event do
          json.id next_event.id
          json.title next_event.title
          json.start_time next_event.start_time.to_i
        end
      end
    end

    json.contacts contacts do |contact|
      json.id contact.id
      json.name contact.name
      json.email contact.email
      json.phone_number contact.phone_number
      json.thumbnail contact.avatar_url
      json.created_at contact.created_at.to_i
    end
  end
end
