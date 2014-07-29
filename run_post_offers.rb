require 'io/console'
require_relative 'zybez.rb'

class Numeric
  def m
    (self * 1000000).to_i
  end

  def k
    (self * 1000).to_i
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

zyb = Zybez.new

ObjectSpace.define_finalizer(zyb, proc { 
  config = read_config
  if config[:delete_offers_on_exit] 
    config[:offers].uniq { |o| o[2] }.each do |o|
      log "Deleting #{explain_offer o}"
      until zyb.delete_offers(o[2]).empty? do end
    end
    zyb.delete_all_offers
    puts "Press ENTER to continue"
    gets
  end
})

old_config = read_config
count = 0

loop do
  if Time.now - File.mtime('config.rb') < 60 || count % 5 == 0
    begin
      config = read_config

      if config[:delete_offers_on_remove]
        deleted_offers = old_config[:offers].clone
        config[:offers].each do |e|
          deleted_offers.delete_if { |o| o[0] == e[0] && o[2] == e[2] }
        end

        deleted_offers.uniq { |o| o[2] }.each do |o|
          log "Deleting #{explain_offer o}" if config[:notifications][:offer_deleted]
          until zyb.delete_offers(o[2]).empty? do end
        end
      end

      items_posted = []
      config[:offers].each do |o|
        next if items_posted.include?(o[2]) # prevents posting buying and selling offer next to eachother
        off = zyb.post_offer_if o[0], o[1], o[2], o[3], 
          (o.length > 4 && o[4] ? config[:note_explicit] % o[4] : config[:note_default]),
          (o.length > 5 ? o[5] : config[:contact_default]), config[:repost_offer_if]
        if off
          log "Posting #{explain_offer o}" if config[:notifications][:offer_posted]
          items_posted << o[2]
        end
      end

      old_config = config
    rescue NotLoggedInException
      log "login as: "
      login = gets.chomp
      log "#{login}'s password: "
      pwd = STDIN.noecho { |io| io.gets }.chomp
      puts
      zyb.login login, pwd
      next
    rescue StandardError => e
      log e
    end
  end
  count += 1
  sleep(60)
end
