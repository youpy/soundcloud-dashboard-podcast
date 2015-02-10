# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/spec_helper'

require 'nokogiri'

describe 'App' do
  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application.new
  end

  describe '/activities' do
    before do
      SoundCloud::User.
        should_receive(:where).
        with(id_md5: 'xxxxx').
        and_return([mock(Object, access_token: 'foo')])

      OAuth2::AccessToken.should_receive(:new).
        with(any_args, 'foo', header_format: 'OAuth %s').
        at_least(1).
        times.
        and_return(@access_token = mock(Object))

      @access_token.should_receive(:get).
        with('/me.json').
        and_return(mock(Object, body: read_fixture('me.json')))
    end

    describe '/activities/:id.xml' do
      before do
        @access_token.should_receive(:get).
          with('/me/activities/tracks/affiliated.json').
          and_return(mock(Object, body: read_fixture('affiliated.json')))
      end

      it 'returns a feed for activities' do
        get '/activities/xxxxx.xml'

        doc = Nokogiri::XML(last_response.body)

        doc.xpath('//title')[0].text.should eql('SoundCloud.com: Dashboard for youpy')
        doc.xpath('//item').should have(50).items

        item = doc.xpath('//item')[0]

        {
          'title' => 'Ce',
          'description' => '',
          'link' => 'http://soundcloud.com/blueangels/ce',
          'guid' => 'http://soundcloud.com/blueangels/ce',
          'author' => 'Blue Angels',
          'itunes:author' => 'Blue Angels',
          'itunes:subtitle' => 'http://soundcloud.com/blueangels/ce'
        }.each do |name, value|
          item.xpath(name)[0].text.should eql(value)
        end

        item.xpath('enclosure')[0]['url'].should eql('http://youpy.jit.su/soundcloud/download.mp3?download_url=http%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F83713890%2Fstream%3Fconsumer_key%3D' + ENV['XC_OAUTH_CONSUMER_KEY'])

        {
          'mp3'  => 44,
          'wav'  => 3,
          'aiff' => 1,
          'm4a'  => 2
        }.each do |ext, num|
          doc.xpath('//enclosure[contains(@url, ".%s")]' % ext).size.should eql(num)
        end
      end
    end

    describe '/activities/favorites/:id.xml' do
      before do
        @access_token.should_receive(:get).
          with('/me/activities/all.json').
          and_return(mock(Object, :body => read_fixture('all.json')))
      end

      it 'returns a feed for activities' do
        get '/activities/favorites/xxxxx.xml'

        doc = Nokogiri::XML(last_response.body)

        doc.xpath('//title')[0].text.should eql('SoundCloud.com: Dashboard Favorites for youpy')
      end
    end

    describe '/activities/my_favorites/:id.xml' do
      before do
        @access_token.should_receive(:get).
          with('/me/favorites.json').
          and_return(mock(Object, body: read_fixture('favorites.json')))
      end

      it 'returns a feed for activities' do
        get '/activities/my_favorites/xxxxx.xml'

        doc = Nokogiri::XML(last_response.body)

        doc.xpath('//title')[0].text.should eql('SoundCloud.com: My Favorites for youpy')
        doc.xpath('//item').should have(50).items

        item = doc.xpath('//item')[0]

        {
          'title' => '2NE1 vs Eero Johannes "FIRE" (A. G. COOK EDIT)',
          'description' => "Remix of 2NE1's \"Fire\" \n\nAs featured in LOGO's Illamasqua project http://illamasqua.logo.ec\n\n",
          'link' => 'http://soundcloud.com/logobrandedculture/2ne1-vs-eero-johannes-fire-a-g',
          'guid' => 'http://soundcloud.com/logobrandedculture/2ne1-vs-eero-johannes-fire-a-g',
          'author' => 'LOGO.EC',
          'itunes:author' => 'LOGO.EC',
          'itunes:subtitle' => 'http://soundcloud.com/logobrandedculture/2ne1-vs-eero-johannes-fire-a-g'
        }.each do |name, value|
          item.xpath(name)[0].text.should eql(value)
        end

        item.xpath('enclosure')[0]['url'].should eql('http://youpy.jit.su/soundcloud/download.mp3?download_url=http%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F79781134%2Fdownload%3Fconsumer_key%3D' + ENV['XC_OAUTH_CONSUMER_KEY'])

        {
          'mp3'  => 47,
          'wav'  => 1,
          'aiff' => 0,
          'm4a'  => 2
        }.each do |ext, num|
          doc.xpath('//enclosure[contains(@url, ".%s")]' % ext).size.should eql(num)
        end
      end
    end
  end
end
