module OAuthHelper
  enable :sessions

  get '/oauth/auth' do
    redirect client.auth_code.authorize_url(redirect_uri: url('/oauth/cb'))
  end

  get '/oauth/cb' do
    access_token = client.auth_code.get_token(
      params[:code],
      {
        redirect_uri: url('/oauth/cb')
      },
      {
        header_format: header_format
      }
    )
    session[:access_token] = access_token.token
    session[:refresh_token] = access_token.refresh_token

    redirect to(settings.oauth_redirect_to)
  end

  def header_format
    'OAuth %s'
  end

  def refresh_token(token, refresh_token)
    OAuth2::AccessToken.new(
      client,
      token,
      header_format: header_format,
      refresh_token: refresh_token
    ).refresh!
  end

  def access_token(token)
    OAuth2::AccessToken.new(
      client,
      token,
      header_format: header_format
    )
  end

  def client
    client = OAuth2::Client.new(
      settings.oauth_consumer_key,
      settings.oauth_consumer_secret,
      {
        site: settings.oauth_site,
        authorize_url: 'https://soundcloud.com/connect',
        token_url: 'https://api.soundcloud.com/oauth2/token'
      })
  end
end
