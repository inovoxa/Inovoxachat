class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :fetch_scheduled_message, only: [:destroy]

  def index
    @scheduled_messages = @conversation.scheduled_messages.order(scheduled_at: :asc)
  end

  def create
    @scheduled_message = @conversation.scheduled_messages.create!(
      permitted_params.merge(account: Current.account, created_by: Current.user)
    )
  end

  # Cancela um agendamento ainda pendente.
  def destroy
    @scheduled_message.canceled!
    head :ok
  end

  private

  def fetch_scheduled_message
    @scheduled_message = @conversation.scheduled_messages.pending.find(params[:id])
  end

  def permitted_params
    params.require(:scheduled_message).permit(:content, :scheduled_at)
  end
end
