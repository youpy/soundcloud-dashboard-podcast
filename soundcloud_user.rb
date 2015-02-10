if mongo_uri = ENV['MONGOHQ_URL']
  Mongoid.database = Mongo::Connection.from_uri(mongo_uri).
    db(URI.parse(mongo_uri).path.gsub(/^\//, ''))
else
  host = 'localhost'
  port = Mongo::Connection::DEFAULT_PORT
  Mongoid.database = Mongo::Connection.new(host, port).db('soundcloud_users')
end

module SoundCloud
  class User
    include Mongoid::Document
    include Mongoid::Timestamps

    field :id_md5, type: String
    field :access_token, type: String
  end
end
