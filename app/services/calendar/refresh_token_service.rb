# Garante um access_token válido para uma CalendarConnection, renovando via
# refresh_token quando expirado (miolo OAuth2 análogo ao
# BaseRefreshOauthTokenService dos canais de e-mail, mas sobre CalendarConnection).
class Calendar::RefreshTokenService
  include CalendarOauthConcern

  def initialize(connection)
    @connection = connection
  end

  def access_token
    return @connection.access_token unless @connection.token_expired?

    refresh!
    @connection.access_token
  end

  private

  def refresh!
    raise 'A refresh_token is not available' if @connection.refresh_token.blank?

    client = @connection.google? ? calendar_google_client : calendar_outlook_client
    token = OAuth2::AccessToken.new(client, @connection.access_token, refresh_token: @connection.refresh_token)
    refreshed = token.refresh!

    @connection.update!(
      access_token: refreshed.token,
      refresh_token: refreshed.refresh_token.presence || @connection.refresh_token,
      expires_at: refreshed.expires_at.present? ? Time.at(refreshed.expires_at).utc : 1.hour.from_now
    )
  end
end
