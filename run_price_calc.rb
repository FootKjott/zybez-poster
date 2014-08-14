require_relative 'zybez'

# TODO:
#   keep track of item counts, merch profits?
#   allow different caps and item ids to be used

class String
  def sanitize_item
    self.downcase
  end
end

class Integer
  def format
    self.to_s.reverse.gsub(/...(?=.)/,'\&,').reverse
  end
end

def print s=''
  $stdout << s
  $stdout.flush
end

trades = [] # []

loop do
  begin
    print "\noffer?> "

    input = gets.strip
    command = input.split.first
    config = read_config

    action = (command[0] == 'b' ? :buying : :selling)
    amount_type = (command[-1] == 'c' ? :coins : :items)

    item = input[(input.index(' ')+1)..-1].sanitize_item

    offers = config[:offers].select { |o|
      o[0] == action &&
      o[2].sanitize_item.include?(item)
    }

    if offers.count != 1
      if offers.count > 1
        offers_list = offers.map { |o| '-' + o[2] }.join("\n")
        puts "Ambiguous offers:\n#{offers_list}"
      end
      puts 'Offer not found' if offers.count == 0
      next
    end

    print "#{amount_type}?> "

    if amount_type == :items
      puts (gets.to_i * offers[0][3]).format
    end
    if amount_type == :coins
      puts (gets.to_i / offers[0][3]).format
    end
  rescue
  end
end
