require 'io/console'
require_relative 'zybez'

old_config = read_config
config = old_config

zyb = Zybez.new old_config

ObjectSpace.define_finalizer(zyb, proc {
  config = read_config
  if config[:delete_offers_on_exit]
    config[:offers].uniq { |o| o[2] }.each do |o|
      log "Deleting #{explain_offer}"
      until zyb.delete_offers(o[2]).empty? do end
    end
    zyb.delete_all_offers
    puts "Press ENTER to continue"
    gets
  end
})

count = 0

while config[:loop_while].call
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
        # prevents posting buying and selling offer next to eachother
        next if items_posted.include?(o[2])

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
