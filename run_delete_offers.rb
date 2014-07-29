require_relative 'zybez.rb'

class Fixnum
  def m
    self * 1000000
  end

  def k
    self * 1000
  end
end

class Float
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

config = read_config
config[:offers].uniq { |o| o[2] }.each do |o|
  log "Deleting #{explain_offer o}"
  until zyb.delete_offers(o[2]).empty? do end
end
zyb.delete_all_offers
puts "Press ENTER to continue"
gets
