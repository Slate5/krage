$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'krage_class'

KRAGE_DIR = Displayable::KRAGE_DIR

def rows_columns
  sleep 0.05
  `stty size`.split(' ').map(&:to_i)
end

krage_profile_id = File.read("#{KRAGE_DIR}/ext/.current_krage_id")
font = `dconf read /org/gnome/terminal/legacy/profiles:/:#{krage_profile_id}/font\
        | grep -Eo "[0-9]+\.?[0-9]*"`.to_f
curr_rows_cols = File.read("#{KRAGE_DIR}/ext/.current_rows_columns") rescue ''

counter = 0

if !`xprop -name Krage`.empty? && `stty size` != curr_rows_cols
  loop do
    rows, columns = rows_columns
    break if rows == 44 && columns == 159
    break if counter > 7 && rows >= 44 && columns >= 159
    counter += 1
    if rows < 44 || columns < 159
      font -= 0.2
    else
      font += 1
    end
    `dconf write /org/gnome/terminal/legacy/profiles:/:#{krage_profile_id}/font\
     "'Monospace Bold #{font}'"`
  end
  `stty size > #{KRAGE_DIR}/ext/.current_rows_columns`
end

spawn("paplay #{KRAGE_DIR}/data/welcome.ogg")

music = ['krage_slavic.ogg', 'krage_western.ogg', 'krage_viking.ogg']

spawn("paplay #{KRAGE_DIR}/data/#{music[rand(3)]}")

at_exit do
  `pkill -f 'paplay.*krage'`
  `reset` if `xprop -name Krage`.empty?
end

Signal.trap('INT') do
  exit
end

def intro(crow)
  puts `clear`
  puts "\e[1mWelcome to The Mighty Krage".center(163)
  puts "\n\n"
  puts "\e[1;30m#{crow}\e[0;1m"
  puts "\n"
end

def new_player
  name = gets.chomp[0..13].gsub("\e", '')
  name = 'Anonymous' if name.empty?
  Krage.new(name)
end

def options_writer(options)
  start_end = options.sum(&:size) < 55 ? ' '*8 : ''
  options.each do |option|
    space = start_end + (option[7] == '⮕' ? ' '*59 : ' '*60)
    puts "#{space} #{option}  \n\n"
  end
end

def options_changer(options, left_right=false)
  options.each_with_index do |choice, idx|
    if choice[7] == '⮕'
      pc_or_wifi = options[idx][-1].ascii_only? ? '' : options[idx][-1]
      if left_right
        pc_or_wifi = pc_or_wifi == '💻' ? '📶' : '💻'
        options[idx][-1] = pc_or_wifi
        break
      end
      other_idx = (idx-1).abs
      reducer = pc_or_wifi.empty? ? -1 : -2
      options[idx] = options[idx][13..reducer]
      options[other_idx] = POINTER + options[other_idx] + pc_or_wifi
      break
    end
  end
end

def ending(player)
  ending_choice = ["#{POINTER}Courageous enough for one more challenge",
                   'I have had enough of this silly game']

  `pkill -f 'paplay.*krage'`
  player.spawn("paplay #{KRAGE_DIR}/data/king.ogg")
  loop do
    player.display('winer')
    puts "\n\n\n"
    puts "\e[1;4;32mWe have a Krage King, behold almighty "\
         "#{player.color.call(player.name.upcase)}!!!\e[0;1m\n\n".center(188)

    options_writer(ending_choice)

    key = `#{KRAGE_DIR}/ext/gen_keyboard`
    case key
    when ''
      if ending_choice[0][7] == '⮕'
        `pkill -f 'paplay.*krage'`
        print "\ec"
        exec("ruby #{KRAGE_DIR}/krage.rb")
      elsif ending_choice[1][7] == '⮕'
        exit
      end
    when "\e[A", "\e[B"
      options_changer(ending_choice)
    end
  end
end

crow_file = File.read("#{KRAGE_DIR}/ext/crow.yaml")
crow = YAML.load(crow_file)

POINTER = "\e[1;33m⮕\e[0m "
game_options = ["#{POINTER}Krage For Softies 💻", 'Krage Under Pressure ']

print "\e[?7l"
intro(crow)
`stty -echo`

loop do
  puts `tput cup 32 60` + 'What type of challenge do you seek?(⇵|⇆)'
  puts "\n"
  options_writer(game_options)
  puts "\n\n"
  puts 'Are you not up to the challenge? Press CTRL+C to exit'.center(159)

  key = `#{KRAGE_DIR}/ext/gen_keyboard`

  case key
  when ''
    if game_options[0][7] == '⮕'
      Krage.class_variable_set(:@@game_with_timer, false)
    elsif game_options[1][7] == '⮕'
      Krage.class_variable_set(:@@game_with_timer, true)
    end
    break
  when "\e[A", "\e[B"
    options_changer(game_options)
  when "\e[C", "\e[D"
    options_changer(game_options, true)
  end
end

space = ' '*71
intro(crow)
print 'How many brave souls will participate?(2-4) '.rjust(102)

while num_players ||= `#{KRAGE_DIR}/ext/gen_keyboard`.to_i
  if num_players.between?(2, 4)
    print `tput cup 32 102` + num_players.to_s
    confirm = `#{KRAGE_DIR}/ext/gen_keyboard`
    if confirm == ''
      `stty echo`
      puts "\n\n"
      if num_players.between?(2, 4)
        print "#{space}\e[1;40m1. Player Name\e[0;30m: "
        player1 = new_player
        print "\n#{space}\e[1;47m2. Player Name\e[0;97m: "
        player2 = new_player
        if num_players > 2
          print "\n#{space}\e[1;42m3. Player Name\e[0;32m: "
          player3 = new_player
          if num_players == 4
            print "\n#{space}\e[1;41m4. Player Name\e[0;31m: "
            player4 = new_player
          end
        end
        break
      end
    elsif confirm.to_i.between?(2, 4)
      num_players = confirm.to_i
    elsif confirm == "\u007F"
      print `tput cup 32 102` + ' '
      num_players = nil
    end
  else
    num_players = nil
  end
end

players = [player1, player2, player3, player4].compact
score = {}

print "\e[?9h"
print "\e[?7l"
`stty -echo`
print "\n\n" * (4 - players.size)
print "\n#{space}\e[0mIacta alea est"
5.times { print '!'; sleep 0.3 }

players.cycle do |player|
  next unless player
  player.generate_coords == 'roll' ? player.roll : redo
  score[player] = player.player_territory; next if player.round == 1

  loop do
    case button ||= player.generate_coords
    when true, 'skip'
      player.show_current_land = false
      player.countdown = '' if Krage.class_variable_get(:@@game_with_timer)
      break
    when 'giveup'
      player.spawn("paplay #{KRAGE_DIR}/data/giveup.ogg")
      player.show_current_land = false
      player.giveup_cleaner
      players[players.index(player)] = nil
      ending(players.compact.last) if players.count(&:itself) < 2
      break
    when /[1-4qwe]/
      player.jokers(button) if button =~ /[qwe]/
      button = nil
      redo
    end
    redo if button = player.choose_place
  end

  players.compact.each do |pl|
    score[pl] = pl.player_territory
  end

  next unless player == players.compact.last
  strongest = score.values.max
  second_strongest = score.values.max(2)[1]
  empty_spaces = 900 - score.values.sum

  if second_strongest + empty_spaces / (players.compact.size-0.75) < strongest
    ending(score.key(strongest))
  end
end
