require './oauth_helper'
require './soundcloud_user'

require 'digest/md5'
require 'cgi'

include OAuthHelper

set :oauth_consumer_key, ENV['XC_OAUTH_CONSUMER_KEY']
set :oauth_consumer_secret, ENV['XC_OAUTH_CONSUMER_SECRET']
set :oauth_site, 'http://api.soundcloud.com'
set :oauth_redirect_to, '/welcome'

get '/' do
  haml :index
end

get '/welcome' do
  access_token_key = session[:access_token_key]
  access_token_secret = session[:access_token_secret]
  access_token = OAuth::AccessToken.new(oauth_consumer, access_token_key, access_token_secret)
  data = JSON.parse(access_token.get('https://api.soundcloud.com/me.json').body)
  id_md5 = Digest::MD5.hexdigest(data['id'].to_s + ENV['XC_ID_SECRET'])

  SoundCloud::User.where(:id_md5 => id_md5).each do |user|
    user.destroy
  end

  SoundCloud::User.create!(:id_md5 => id_md5, :access_token_key => access_token_key, :access_token_secret => access_token_secret)

  @id_md5 = id_md5

  haml :welcome
end

get '/activities/:id.xml' do |id_md5|
  user = SoundCloud::User.where(:id_md5 => id_md5).first
  access_token = OAuth::AccessToken.new(oauth_consumer, user.access_token_key, user.access_token_secret)
  data = JSON.parse(access_token.get('https://api.soundcloud.com/me/activities/tracks/affiliated.json').body)
  me = JSON.parse(access_token.get('https://api.soundcloud.com/me.json').body)

  builder do |xml|
    xml.instruct! :xml, :version => '1.0'
    xml.rss :version => "2.0", 'xmlns:itunes' => 'http://www.itunes.com/dtds/podcast-1.0.dtd' do
      xml.channel do
        xml.title "SoundCloud.com: Dashboard Podcast for %s" % me['username']
        xml.description "SoundCloud.com: Dashboard Podcast for %s" % me['username']
        xml.link url('/activities/%s.xml' % id_md5)

        data['collection'].each do |activity|
          if activity['type'] == 'track'
            origin = activity['origin']
            if origin['downloadable'] && origin['download_url']
              enclosure_url = origin['download_url']
              format = origin['original_format']
            else
              enclosure_url = origin['stream_url']
              format = 'mp3'
            end

            if enclosure_url
              enclosure_url += '?consumer_key=hE1HLJfuvbBHU3fX2S56w'

              xml.item do
                xml.title origin['title']
                xml.description origin['description']
                xml.link origin['permalink_url']
                xml.guid origin['permalink_url']
                xml.enclosure :url => 'http://youpy.no.de/soundcloud/download.%s?download_url=%s' % [format, CGI.escape(enclosure_url.sub(/^https/, 'http'))]
                xml.author origin['user']['username']
                xml.itunes :author, origin['user']['username']
                xml.itunes :summary, origin['description']
              end
            end
          end
        end
      end
    end
  end
end

get '/activities/favorites/:id.xml' do |id_md5|
  user = SoundCloud::User.where(:id_md5 => id_md5).first
  access_token = OAuth::AccessToken.new(oauth_consumer, user.access_token_key, user.access_token_secret)
  data = JSON.parse(access_token.get('https://api.soundcloud.com/me/activities/all.json').body)
  me = JSON.parse(access_token.get('https://api.soundcloud.com/me.json').body)

  builder do |xml|
    xml.instruct! :xml, :version => '1.0'
    xml.rss :version => "2.0", 'xmlns:itunes' => 'http://www.itunes.com/dtds/podcast-1.0.dtd' do
      xml.channel do
        xml.title "SoundCloud.com: Dashboard Favorite Podcast for %s" % me['username']
        xml.description "SoundCloud.com: Dashboard Favorite Podcast for %s" % me['username']
        xml.link url('/activities/favorites/%s.xml' % id_md5)

        data['collection'].each do |activity|
          if activity['type'] == 'favoriting'
            origin = activity['origin']['track']
            enclosure_url = origin['stream_url']
            format = 'mp3'
            username = origin['permalink_url'].match(/http:\/\/soundcloud\.com\/([^\/]+)/)[1]

            if enclosure_url
              enclosure_url += '?consumer_key=hE1HLJfuvbBHU3fX2S56w'

              xml.item do
                xml.title origin['title']
                xml.description origin['title']
                xml.link origin['permalink_url']
                xml.guid origin['permalink_url']
                xml.enclosure :url => 'http://youpy.no.de/soundcloud/download.%s?download_url=%s' % [format, CGI.escape(enclosure_url.sub(/^https/, 'http'))]
                xml.author username
                xml.itunes :author, username
              end
            end
          end
        end
      end
    end
  end
end
