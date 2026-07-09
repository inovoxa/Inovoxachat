class Calendar::MicrosoftCallbacksController < Calendar::BaseCallbacksController
  private

  def provider_name
    'outlook'
  end

  def oauth_client
    calendar_outlook_client
  end
end
