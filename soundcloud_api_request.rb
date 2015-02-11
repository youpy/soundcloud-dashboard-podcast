require 'forwardable'

class FaradayMiddleware::SoundCloudApiRequest < Faraday::Middleware
  extend Forwardable
  def_delegators :'Faraday::Utils', :parse_query, :build_query

  def initialize(app = nil, options = {})
    super(app)
    @options = options
  end

  def call(env)
    params = { :client_id => @options[:client_id] }.update query_params(env[:url])
    env[:url].query = build_query params
    @app.call env
  end

  # https://github.com/lostisland/faraday_middleware/blob/master/lib/faraday_middleware/request/oauth2.rb#L51
  def query_params(url)
    if url.query.nil? or url.query.empty?
      {}
    else
      parse_query url.query
    end
  end
end
