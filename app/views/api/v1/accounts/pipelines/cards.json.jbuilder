json.payload do
  json.array! @pipeline.pipeline_stages do |stage|
    conversations = stage.conversations
                         .where(last_activity_at: @since..)
                         .includes(:assignee, contact: { avatar_attachment: :blob })
                         .order(last_activity_at: :desc)
    contacts = stage.contacts.where(created_at: @since..).order(created_at: :desc)

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
      json.last_activity_at conversation.last_activity_at.to_i
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
