require './oauth_helper'
require './soundcloud_user'
require './soundcloud_api_request'

require 'digest/md5'
require 'cgi'
require 'builder'

include OAuthHelper

set :oauth_consumer_key, ENV['XC_OAUTH_CONSUMER_KEY']
set :oauth_consumer_secret, ENV['XC_OAUTH_CONSUMER_SECRET']
set :oauth_site, 'https://api.soundcloud.com'
set :oauth_redirect_to, '/welcome'
set :cache, Dalli::Client.new(
  ENV['MEMCACHIER_SERVERS'],
  username: ENV['MEMCACHIER_USERNAME'],
  password: ENV['MEMCACHIER_PASSWORD'],
  expires_in: 7.day
)

def build_xml(title, path)
  builder do |xml|
    xml.instruct! :xml, version: '1.0'
    xml.rss version: "2.0", 'xmlns:itunes' => 'http://www.itunes.com/dtds/podcast-1.0.dtd' do
      xml.channel do
        xml.title title
        xml.description title
        xml.link url(path)

        yield xml
      end
    end
  end
end

def build_item(xml, item, enclosure_url, format, updated_at = nil, username = nil)
  enclosure_url += '?consumer_key=' + settings.oauth_consumer_key

  xml.item do
    xml.title item['title']
    xml.description item['description']
    xml.link item['permalink_url']
    xml.guid item['permalink_url']

    if updated_at
      xml.pubDate updated_at.utc.rfc822
    end

    xml.enclosure url: 'http://soundcloud-download.appspot.com/download.%s?url=%s' % [format.downcase, CGI.escape(enclosure_url.sub(/^https/, 'http'))]
    xml.author username || item['user']['username']
    xml.itunes :author, username || item['user']['username']
    xml.itunes :subtitle, item['permalink_url']
    xml.itunes :summary, item['description']
    xml.itunes :duration, duration_to_str(item['duration'])

    if item['artwork_url']
      xml.itunes :image, href: item['artwork_url'].sub(/\?\w+$/, '').sub(/large/, 'original')
    end
  end
end

def duration_to_str(duration)
  [60, 60, 24].inject([duration / 1000, []]) do |(dur, digits), n|
    digit = (dur % n).to_s
    digits << (digit.size < 2 ? '0' + digit : digit)
    [dur / n, digits]
  end[1].reverse.join(':')
end

get '/' do
  haml :index
end

get '/welcome' do
  access_token = access_token(session[:access_token])
  data = JSON.parse(access_token.get('/me.json').body)
  id_md5 = Digest::MD5.hexdigest(data['id'].to_s + ENV['XC_ID_SECRET'])

  SoundCloud::User.where(id_md5: id_md5).each do |user|
    user.destroy
  end

  SoundCloud::User.create!(
    id_md5: id_md5,
    access_token: session[:access_token],
    refresh_token: session[:refresh_token]
  )

  @tracks_path = '/activities/%s.xml' % id_md5
  @favorites_path = '/activities/favorites/%s.xml' % id_md5
  @my_favorites_path = '/activities/my_favorites/%s.xml' % id_md5

  haml :welcome
end

get '/activities/:id.xml' do |id_md5|
  user = SoundCloud::User.where(id_md5: id_md5).first
  refresh_token!(user)
  access_token = access_token(user.access_token)
  data = JSON.parse(access_token.get('/me/activities/tracks/affiliated.json').body)
  me = JSON.parse(access_token.get('/me.json').body)

  build_xml(
    'SoundCloud.com: Dashboard for %s' % me['username'],
    '/activities/%s.xml' % id_md5) do |xml|
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
          build_item(xml, origin, enclosure_url, format, Time.parse(activity['created_at']))
        end
      end
    end
  end
end

get '/activities/my_favorites/:id.xml' do |id_md5|
  user = SoundCloud::User.where(id_md5: id_md5).first
  refresh_token!(user)
  access_token = access_token(user.access_token)
  data = JSON.parse(access_token.get('/me/favorites.json').body)
  me = JSON.parse(access_token.get('/me.json').body)

  build_xml(
    'SoundCloud.com: My Favorites for %s' % me['username'],
    '/my_favorites/%s.xml' % id_md5) do |xml|
    data.each do |track|
      if track['kind'] == 'track'
        if track['downloadable'] && track['download_url']
          enclosure_url = track['download_url']
          format = track['original_format']
        else
          enclosure_url = track['stream_url']
          format = 'mp3'
        end

        if enclosure_url
          build_item(xml, track, enclosure_url, format, Time.parse(track['created_at']))
        end
      end
    end
  end
end

get '/activities/favorites/:id.xml' do |id_md5|
  user = SoundCloud::User.where(id_md5: id_md5).first
  refresh_token!(user)
  access_token = access_token(user.access_token)
  data = JSON.parse(access_token.get('/me/activities/all.json').body)
  me = JSON.parse(access_token.get('/me.json').body)

  build_xml(
    'SoundCloud.com: Dashboard Favorites for %s' % me['username'],
    '/activities/favorites/%s.xml' % id_md5) do |xml|
    data['collection'].each do |activity|
      if activity['type'] == 'favoriting'
        origin = activity['origin']['track']
        enclosure_url = origin['stream_url']
        format = 'mp3'
        username = username(access_token, origin['user_uri'])

        if enclosure_url
          build_item(xml, origin, enclosure_url, format, Time.parse(activity['created_at']), username)
        end
      end
    end
  end
end

get '/user_tracks' do
  name = params[:name]
  location = http.get(
    '/resolve.json',
    {
      url: 'http://soundcloud.com/' + name,
    }
  ).body['location']
  id = http.get(location).body['id']

  redirect url('/user_tracks/%i.xml' % id)
end

get '/user_tracks/:id.xml' do |user_id|
  response = http.get('/users/%i.json' % user_id)
  username = response.body['username']
  tracks = http.get('/users/%i/tracks.json' % user_id).body

  build_xml(
    'SoundCloud.com: Tracks: %s' % username,
    '/user_tracks/%i.xml' % user_id) do |xml|
    tracks.each do |track|
      if track['downloadable'] && track['download_url']
        enclosure_url = track['download_url']
        format = track['original_format']
      else
        enclosure_url = track['stream_url']
        format = 'mp3'
      end

      if enclosure_url
        build_item(xml, track, enclosure_url, format, Time.parse(track['created_at']))
      end
    end
  end
end

helpers do
  def to_itpc(*args)
    to(*args).sub(/^https?/, 'itpc')
  end

  def username(access_token, user_url)
    unless username = settings.cache.get(user_url)
      username = JSON.parse(access_token.get(user_url + '.json').body)['username']
      settings.cache.set(user_url, username)
    end

    username
  end

  def refresh_token!(user)
    access_token = refresh_token(user.access_token, user.refresh_token)
    user.access_token = access_token.token
    user.refresh_token = access_token.refresh_token
    user.save
  end

  def http
    Faraday.new(url: settings.oauth_site) do |faraday|
      faraday.use FaradayMiddleware::SoundCloudApiRequest, :client_id => settings.oauth_consumer_key
      # faraday.response :logger
      faraday.adapter Faraday.default_adapter
      faraday.use FaradayMiddleware::ParseJson
    end
  end
end
