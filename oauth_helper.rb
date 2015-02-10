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
    token = access_token.token
    session[:access_token] = token

    redirect to(settings.oauth_redirect_to)
  end

  def header_format
    'OAuth %s'
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
