class Calendar::GoogleCallbacksController < Calendar::BaseCallbacksController
  private

  def provider_name
    'google'
  end

  def oauth_client
    calendar_google_client
  end
end
