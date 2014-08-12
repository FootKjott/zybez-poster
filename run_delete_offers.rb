require_relative 'zybez.rb'

config = read_config

zyb = Zybez.new config

config[:offers].uniq { |o| o[2] }.each do |o|
  log "Deleting #{explain_offer o}"
  until zyb.delete_offers(o[2]).empty? do end
end
zyb.delete_all_offers
puts "Press ENTER to continue"
gets
