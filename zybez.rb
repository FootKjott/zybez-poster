require 'open-uri'
require 'cgi'
require_relative 'browser.rb'

class Numeric
  def m
    (self * 1000000).round
  end

  def k
    (self * 1000).round
  end
end

def log message=''
  puts "#{Time.now}: #{message}"
end

def read_config
  eval(File.read('config.rb'))
end

def explain_offer offer
  offer.map { |e| (e.is_a?(String) ? "\"#{e}\"" : e) }.join ' '
end

class NotLoggedInException < RuntimeError

end

class Zybez
  attr_accessor :config

  def initialize config
    @item_ids = Hash.new do |hash, key|
      hash[key] = Zybez.lookup(key)['id']
    end

    @config = config

    @browser = Browser.new
  end

  def rs_name
    return @rsn if @rsn
    res = @browser.get('http://forums.zybez.net/index.php?app=priceguide&module=public&section=preferences&do=manageChars')
    begin
      @rsn = /<td class="pre"><a href="http:\/\/forums.zybez.net\/runescape-2007-prices\/player\/([^"]+)">\1<\/a><\/td>/.match(res.body)[1]
    rescue NoMethodError
      raise NotLoggedInException
    end
  end

  def login user, password
    # Get login form auth_key and cookies from login form
    res = @browser.get('http://forums.zybez.net/index.php?app=curseauth&module=global&section=login')

    # Post login details
    @browser.post "http://forums.zybez.net/index.php?app=curseauth&module=global&section=login&do=process", {
      'rememberMe' => '1',
      'auth_key' => /<input type='hidden' name='auth_key' value='([0-9a-fA-F]+)'/.match(res.body)[1],
      'ips_username' => user,
      'ips_password' => password,
      'submit' => 'Login',
      'invisible' => '5'
    }
  end

  def post_offer_if action, quantity, item_id, price, notes, contact, proc
    lookup = Zybez.lookup item_id
    @item_ids[item_id] = lookup['id'] if item_id.is_a? String
    item_id = lookup['id']

    if @config[:notifications][:bad_price]
      r_offers = lookup['offers'].select { |o|
        o['selling'] == (action == :selling ? 1 : 0)
      }.map { |o| o['price'] }.take(10)

      if action == :selling && r_offers.min > price or
          action != :selling && r_offers.max < price
        log "**Bad price detected for #{explain_offer [action, quantity,
                                item_id, price]}**"
      end
    end

    return if lookup['offers'][0]['rs_name'] == rs_name && Time.now.to_i - lookup['offers'][0]['date'] < 600

    most_recent_offer = lookup['offers'].select { |o|
      o['rs_name'] == rs_name &&
      o['selling'] == (action == :selling ? 1 : 0) &&
      o['price'] == price
    }.max_by { |o|
      o['date']
    }

    return unless !most_recent_offer || proc.call(most_recent_offer, lookup['offers'].index(most_recent_offer))

    post_offer action, quantity, item_id, price, notes, contact
  end

  def post_offer action, quantity, item_id, price, notes=nil, contact=:pm
    item_id = @item_ids[item_id] if item_id.is_a? String
    res = item_page(item_id).response

    char_id_match_data = /<input type="hidden" name="character_id" value="([0-9]+)" \/>/.match(res.body)

    raise NotLoggedInException if char_id_match_data.nil?

    @browser.post "http://forums.zybez.net/index.php?app=priceguide&module=public&section=action&do=trade-add", {
      'auth' => /<input type="hidden" name="auth" value="([0-9a-fA-F]+)"/.match(res.body)[1],
      'id' => item_id,
      'type' => (action == :selling ? 1 : 0),
      'qty' => quantity,
      'price' => price,
      'character_id' => char_id_match_data[1],
      'contact' => (contact == :cc ? 3 : 1),
      'notes' => CGI.escape(notes)
    }
  end

  def self.lookup item
    item = CGI.escape item.to_s
    url = "http://forums.zybez.net/runescape-2007-prices/api/item/#{item}"
    ret = JSON.parse(open(url).read)
    throw "Zybez lookup failed (#{ret['error']}: #{url}" if ret['error']
    return ret
  end

  def delete_offers item_id
    item_id = @item_ids[item_id] if item_id.is_a? String
    delete_offers_from_page item_page(item_id).body
  end

  def delete_all_offers
    delete_offers_from_page @browser.get("http://forums.zybez.net/runescape-2007-prices").body
  end

  def delete_offers_from_page page_body
    page_body.scan(/index.php\?app=priceguide&amp;module=public&amp;section=action&amp;do=trade-delete&amp;id=[0-9]+&amp;tid=[0-9]+&amp;auth=[0-9a-fA-F]+/).each do |d|
      @browser.get("http://forums.zybez.net/#{d.gsub('&amp;', '&')}")
    end
  end

  def logged_in?
    /<input type="hidden" name="character_id" value="([0-9]+)" \/>/.match(item_page(100).body)
  end

  def item_page item_id
    item_id = @item_ids[item_id] if item_id.is_a? String
    @browser.get("http://forums.zybez.net/?app=priceguide&module=public&section=item&id=#{item_id}")
  end
end
