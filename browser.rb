require 'net/http'
require 'uri'
require 'json'
require 'open-uri'
require 'cgi'

class Browser
  def initialize cookies_file='cookies.json'
    @cookies_file = cookies_file

    @con = Hash.new do |hash, key|
      hash[key] = Net::HTTP.new key
    end

    begin
      @cookies = JSON.parse File.read cookies_file
    rescue
      @cookies = { }
    end

    @headers = {
      'Cookie' => Browser.encode_cookies(@cookies)
    }
  end

  def get url
    uri = URI(url)
    follow_response @con[uri.host].get("#{uri.path}?#{uri.query}", @headers).response
  end

  def post url, data
    uri = URI(url)
    post_data = Browser.hash_to_http_data data
    follow_response @con[uri.host].post("#{uri.path}?#{uri.query}", post_data, @headers).response
  end

  def follow_response res
    set_cookies Browser.decode_cookies res['set-cookie'] if res['set-cookie']
    return get res['Location'] if res['Location']
    res
  end

  def [](key)
    @con[key]
  end

  def set_cookies hsh
    @cookies.merge! hsh
    @headers['Cookie'] = Browser.encode_cookies(@cookies)
    File.open(@cookies_file, 'w') { |file| file.write @cookies.to_json }
  end

  def self.decode_cookies cookie_header
    Hash[cookie_header.gsub(/expires=[^;]+; /, '').split(', ').map { |c|
      c.split('; ')[0].split('=', 2)
    }]
  end

  def self.encode_cookies cookies
    cookies.map { |k, v|
      "#{k}=#{v}"
    }.join('; ')
  end

  def self.hash_to_http_data hash
    hash.map { |k, v|
      "#{k}=#{v}"
    }.join('&')
  end
end
