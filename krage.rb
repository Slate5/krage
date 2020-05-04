# frozen_string_literal: true

sleep 0.05
print "\e[?25l\e[?7l"
SILENT = `ps x | grep '[p]aplay.*echo.ogg'`.empty?
STTY_STATE = `stty -g`.freeze
KRAGE_DIR = File.expand_path(__dir__)
krage_win_active = !`xprop -name Krage 2> /dev/null`.empty? rescue true
`stty -echo`

at_exit do
  `pkill -f 'paplay.*echo.ogg'` unless SILENT
  `pkill -9 -f 'paplay.*krage'`
  `reset` unless krage_win_active
end

unless RUBY_VERSION.to_f > 2.4
  print `tput cup 22 70` if krage_win_active
  STDERR.puts 'Require ruby > 2.4'
  sleep 2 if krage_win_active
  exit 1
end

$LOAD_PATH.unshift("#{KRAGE_DIR}/lib")
require 'krage_class'

CROW = YAML.load(File.read("#{KRAGE_DIR}/ext/crow.yaml"))
POINTER = "\e[33m⮕\e[0m "
FINAL_OPTIONS = ["#{POINTER}Courageous enough for one more challenge  ",
                 'I have had enough of this silly game']
game_options = [+"#{POINTER}Krage For Softies 🔰 ", 'Krage Under Pressure ']
music = ['krage_slavic.ogg', 'krage_western.ogg',
         'krage_viking.ogg', 'krage_indigenous.ogg']

krage_profile_id = File.read("#{KRAGE_DIR}/ext/.current_krage_id")
font = `dconf read /org/gnome/terminal/legacy/profiles:/:#{krage_profile_id}/font\
        | grep -Eo "[0-9]+\.?[0-9]*"`.to_f
curr_rows_cols = File.read("#{KRAGE_DIR}/ext/.current_rows_columns") rescue ''

if krage_win_active && curr_rows_cols != `stty size`
  begin
    sleep 0.05
    rows, columns = `stty size`.split(' ').map(&:to_i)
    if rows < 44 || columns < 159
      font -= rows + columns < 170 ? 0.5 : 0.1
      status_change = 'reducing'
    else
      font += rows + columns > 235 ? 0.5 : 0.1 if status_change == 'adding'
      status_change = 'adding'
    end
    font_status ||= status_change
    `dconf write /org/gnome/terminal/legacy/profiles:/:#{krage_profile_id}/font\
     "'Monospace Bold #{font}'"`
  end while font_status == status_change
  sleep 0.05
  `stty size > #{KRAGE_DIR}/ext/.current_rows_columns`
end

rows, columns = `stty size`.split(' ').map(&:to_i)
NS = krage_win_active ? (rows-44) / 2 : 0
WE = krage_win_active ? (columns-159) / 2 : 0

spawn("paplay #{KRAGE_DIR}/data/welcome.ogg") unless SILENT
spawn("paplay #{KRAGE_DIR}/data/#{music[rand(4)]}")
`pkill -STOP -f 'paplay.*krage_' &` if SILENT

Displayable.intro
loop do
  print `tput cup #{32+NS} #{60+WE}` + "What type of challenge do you seek?(⇵|⇆)\n\n"
  Displayable.write_options(game_options)
  puts "\n\n"
  puts "Aren't you ready for the challenge? Press CTRL+C to exit".rjust(108+WE)

  key = `#{KRAGE_DIR}/ext/gen_keyboard`

  case key
  when ''
    GAME_HARD = game_options.any?(/⚔️/)
    GAME_WITH_TIMER = game_options[1][5] == '⮕'
    HANDICAP = (GAME_HARD ? 0.15 : 0.45) + (GAME_WITH_TIMER ? 0.25 : 0)
    break
  when "\e[A", "\e[B"
    Displayable.change_option(game_options)
  when "\e[C", "\e[D"
    Displayable.change_option(game_options, true)
  end
end

space = ' ' * (71+WE)
print_input_txt = ->(n) { print "\n#{space}\e[4#{n}m#{n}. Player Name:\e[0m " }
Displayable.intro
print "\e[?25hHow many brave souls will participate?(2-4) ".rjust(108+WE)

while num_players ||= `#{KRAGE_DIR}/ext/gen_keyboard`.to_i
  if num_players.between?(2, 4)
    print `tput cup #{32+NS} #{102+WE}` + num_players.to_s
    confirm = `#{KRAGE_DIR}/ext/gen_keyboard`
    if confirm == ''
      `stty echo`
      puts "\n"
      NUM_OF_PL = num_players
      print_input_txt.call(1)
      player1 = Krage.create_new_player
      print_input_txt.call(NUM_OF_PL == 2 ? 4 : 2)
      player2 = Krage.create_new_player
      if num_players > 2
        print_input_txt.call(3)
        player3 = Krage.create_new_player
        if num_players == 4
          print_input_txt.call(4)
          player4 = Krage.create_new_player
        end
      end
      break
    elsif confirm.to_i.between?(2, 4)
      num_players = confirm.to_i
    elsif confirm == "\u007F"
      print "\e[1D \e[1D"
      num_players = nil
    end
  else
    num_players = nil
  end
end

players = [player1, player2, player3, player4].compact
score = {}

print "\e[?25l\e[?1000h"
`stty -echo -icanon -icrnl`
print "\n\n" * (4-players.size)
print "\n#{space}\e[0mAlea iacta est"
5.times { print '!'; sleep 0.2 }

players.cycle do |player|
  next unless player
  player.generate_coords == 'r' ? player.roll : redo
  next score[player] = player.calc_player_territory if player.round == 1

  loop do
    case button ||= player.generate_coords
    when Array
      button = player.choose_place
      button.to_s =~ /^[sg]$/ ? redo : break if button
    when /[1-4qwe]/
      player.jokers(button) if button =~ /[qwe]/
    when 's'
      break player.spawn("paplay #{KRAGE_DIR}/data/skip.ogg")
    when 'g'
      player.spawn("paplay #{KRAGE_DIR}/data/giveup.ogg")
      score.delete(player)
      player.clear_giveuper
      players[players.index(player)] = nil
      players.compact.last.final_choice if players.count(&:itself) < 2
      break
    end
  end

  player.show_current_land = false
  if score[player]
    if player.eater
      player.eater = false
      score.each_key do |pl|
        score[pl] = pl.calc_player_territory
      end
    else score[player] = player.calc_player_territory
    end
  end
  Krage.class_variable_set(:@@show_turn, true)
  player.countdown = '' if GAME_WITH_TIMER

  next unless player.p_num >= Krage.class_variable_get(:@@p_info).keys.max
  strongest = score.values.max
  second_strongest = score.values.max(2)[1]
  empty_spaces = Krage.class_variable_get(:@@map).flatten.count('___')

  if second_strongest + empty_spaces / (score.size-HANDICAP) < strongest
    score.key(strongest).final_choice
  end
end
