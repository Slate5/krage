# frozen_string_literal: true

require 'yaml'

module Displayable

  STUBS = { 2 => "\e[95;45m Fields\e[35m\e]8;;More Info\e\\📖\e]8;;\e\\\e[37m ",
            4 => "\e[95;45m Percent:\e[37m ",
            6 => "\e[95;45m Jokers\e[35m\e]8;;More Info\e\\📖\e]8;;\e\\\e[37m ",
            8 => "\e[95;45m  ROTATE\e[37m  ",
            9 => "\e[95;45m  REROLL\e[37m  ",
            10 => "\e[95;45m  EAT\e[37m     ",
            12 => "\e[95;45m Timely:\e[37m  ",
            13 => "\e[95;45m Accuracy:\e[37m" }.freeze

  CHK_TIMER_STUBS = ->(n) { GAME_WITH_TIMER && [12, 13, 28, 29].include?(n) }
  SPACE = ' ' * 18
  HID = "\e[8;0;8;1m"

  LOADING = ["\e[36m\e]8;;Music On\e\\🕧\e]8;;\e\\",
             "\e[36m\e]8;;Music On\e\\🕘\e]8;;\e\\",
             "\e[36m\e]8;;Music On\e\\🕛\e]8;;\e\\",
             "\e[36m\e]8;;Music On\e\\⏸️ \e]8;;\e\\"].freeze

  @@map = Array.new(30) { Array.new(30) { '___' } }
  @@music = @@sfx = SILENT ? false : true
  @@music_icon = LOADING[3] if SILENT
  @@previous_music_status = false
  @@show_turn = true
  @@img_info = nil
  @@p_info = {}

  @@left_bird = YAML.load(File.read("#{KRAGE_DIR}/ext/left_bird.yaml"))
  @@right_bird = YAML.load(File.read("#{KRAGE_DIR}/ext/right_bird.yaml"))
  @@players_turn = YAML.load(File.read("#{KRAGE_DIR}/ext/players_turn.yaml"))

  String.class_eval do
    def indent
      WE == 0 ? self : "\e[#{WE}C" + self.gsub(/\n/, "\n\e[#{WE}C")
    end
  end

  def self.intro
    print `clear; tput cup #{NS+1} #{WE}`
    puts 'Welcome to The Mighty Krage'.rjust(94)
    print "\n\n\e[30m#{CROW.indent}\e[0m\n\n"
  end

  def self.write_options(options)
    indentation = options == FINAL_OPTIONS ? '' : ' ' * 10
    options.each do |option|
      puts indentation + (option[5] == '⮕' ? ' ' * (59+WE) : ' ' * (60+WE)) +
           option + "  \n\n"
    end
  end

  def self.change_option(options, left_right=false)
    options.each_with_index do |choice, idx|
      next if choice[5] != '⮕'
      easy_hard = options[idx][-2..-1]
      if left_right
        options[idx][-2..-1] = easy_hard == '🔰 ' ? '⚔️' : '🔰 '
        break
      end
      other_idx = (idx-1).abs
      options[idx] = options[idx][11..-3]
      options[other_idx] = POINTER + options[other_idx] + easy_hard
      break
    end
  end

  def display(winer=nil)
    @@display_str = +''
    @land_rows_num = y_len
    if @@music != @@previous_music_status
      @@previous_music_status = @@music
      @@music_icon = @@music ? hover(36, 'Music Off', '🎶') : hover(36, 'Music On', '🕒')
      unless @@music
        Thread.new do
          LOADING.each do |icon|
            4.times { sleep 0.128; Thread.exit if @@music }
            @@music_icon = icon
            print `tput cup #{NS} #{151+WE}` + icon
          end
        end
      end
    end
    sfx_icon = @@sfx ? hover(36, 'SFX Off', '🔊') : hover(36, 'SFX On', '🔇')
    close_sign = hover('40;30', 'Close', " ❌ \e[0m")
    map_border = "#{SPACE}\e[36;40m#{'KRAGE'.center(123)}\e[0m#{SPACE}\n"
    @@display_str << "#{' '*147}#{sfx_icon}  #{@@music_icon}  #{close_sign}\n"
    @@display_str << map_border
    shovel_map_lines
    @@display_str << map_border
    return (print `clear && tput cup #{NS}` + @@display_str.indent) if winer
    @@display_str << (GAME_WITH_TIMER ? display_timer : ' '*159 + "\n")

    console_rows = [@@left_bird, construct_left_buttons, prepare_console_center,
                    construct_right_buttons, @@right_bird].transpose.flatten

    console_rows.each do |row_element|
      if show_current_land
        if @land_rows_num > 0 && row_element == 'empty land row'
          @land_rows_num -= 1
          row_element = create_current_land_row
        elsif row_element == 'empty land row'
          row_element = ' ' * 45
        end
      elsif row_element == 'empty land row'
        row_element = ' ' * 45
      end
      @@display_str << row_element
    end
    print `tput cup #{NS}` + @@display_str.indent
    show_player_turn if @@show_turn
  end

  def hover(color, popup, txt)
    "\e[#{color}m\e]8;;#{popup}\e\\#{txt}\e]8;;\e\\"
  end

  def shovel_map_lines
    30.times do |line|
      case line
      when 0 then shovel_line(line, 1, 2, 0)
      when 2, 4, 6 then shovel_line(line, 1, 2, line/2, STUBS[line])
      when 8, 9, 10 then shovel_line(line, 1, 2, line-4, STUBS[line])
      when 16 then shovel_line(line, 3, 4, 0)
      when 18, 20, 22 then shovel_line(line, 3, 4, line/2-8, STUBS[line-16])
      when 24, 25, 26 then shovel_line(line, 3, 4, line-20, STUBS[line-16])
      when CHK_TIMER_STUBS
        case line
        when 12, 13
          shovel_line(line, 1, 2, line-5, STUBS[line])
        when 28, 29
          shovel_line(line, 3, 4, line-21, STUBS[line-16])
        end
      else shovel_line(line)
      end
    end
  end

  def shovel_line(line, left_pl=nil, right_pl=nil, info=nil, stub='')
    if info
      if @@p_info[left_pl]
        left_table_line = construct_table_line(left_pl, info, stub)
      end
      if @@p_info[right_pl]
        right_table_line = construct_table_line(right_pl, info, stub)
      end
    elsif line < 12
      left_table_line = "\e[45m" + SPACE if @@p_info[1]
      right_table_line = "\e[45m" + SPACE if @@p_info[2]
    elsif line.between?(17, 27)
      left_table_line = "\e[45m" + SPACE if @@p_info[3]
      right_table_line = "\e[45m" + SPACE if @@p_info[4]
    end

    left_table_line ||= SPACE
    right_table_line ||= SPACE

    @@display_str << left_table_line + "\e[40m  \e[0m"
    @@map[line].each_with_index do |point, idx|
      @@display_str << (idx > 0 ? '|' + point : point)
    end
    @@display_str << "\e[40m  \e[0m#{right_table_line}\e[0m\n"
  end

  def construct_table_line(player_side, info, stub)
    if info == 0
      if p_num == player_side
        color.call("\e[5m👉\e[25m#{name.center(14)}\e[5m👈")
      else @@p_info[player_side][0]
      end
    else
      reduce_ljust = case info
                     when 1, 3 then 27
                     when 2 then -1
                     when 7, 8 then -@@p_info[player_side][info].size
                     else 0
                     end

      (stub + @@p_info[player_side][info]).ljust(31+reduce_ljust)
    end
  end

  def display_timer
    green = 180
    red = 7
    timer_str = +"#{' '*62}⏳"
    31.times do |t|
      if @countdown&.size&.<= t
        timer_str << "\e[48;2;#{red};#{green};0m "
      else timer_str << ' '
      end
      green -= 5
      red += 8
    end
    timer_str << "\e[0m⌛#{' '*62}\n"
  end

  def construct_left_buttons
    default_info = if round < 1
                     'Roll will place a land in your quadrant'\
                     " of the map, ROLL #{color.call(name)}!"
                   elsif show_current_land
                     "Now #{color.call(name)}, place your land"\
                     " on the map or use joker if there's any!"
                   else
                     "It is your turn #{color.call(name)}, ROLL!"
                   end

    if show_current_land
      ["\e[45m        \e[0m",
       "\e[45m  ROLL  \e[0m",
       "\e[45m        \e[0m",
       hover(33, 's', "        \e[0m") + ' '*10,
       hover(33, 's', "  \e[36mSKIP\e[33m  \e[0m") + ' '*10,
       hover(33, 's', "        \e[0m") + ' '*10,
       hover(91, 'g', "        \e[0m") + ' '*20,
       hover(91, 'g', " \e[36mGIVEUP\e[91m \e[0m") + ' '*20,
       hover(91, 'g', "        \e[0m") + ' '*85,
       "INFO: \e[37m#{@@img_info||default_info} \e[30m=".center(137, '=')]
    else
      [hover(32, 'r', "        \e[0m"),
       hover(32, 'r', "  \e[36mROLL\e[32m  \e[0m"),
       hover(32, 'r', "        \e[0m"),
       "\e[45m        \e[0m#{' '*10}",
       "\e[45m  SKIP  \e[0m#{' '*10}",
       "\e[45m        \e[0m#{' '*10}",
       "\e[45m        \e[0m#{' '*20}",
       "\e[45m GIVEUP \e[0m#{' '*20}",
       "\e[45m        \e[0m#{' '*85}",
       "INFO: \e[37m#{@@img_info||default_info} \e[30m=".center(137, '=')]
    end
  end

  def construct_right_buttons
    unavailable = "\e[36;45m" unless show_current_land
    rtt_off = joker_num[0] == 0 ? HID : unavailable
    rrl_off = joker_num[1] == 0 ? HID : unavailable
    eat_off = joker_num[2] == 0 ? HID : unavailable
    eat_off = "\e[36;45m" if GAME_HARD && round < 4
    active = @eater ? "\e[32m" : "\e[36m"

    [rtt_off ? rtt_off + '        ' : hover('97;107', 'q', '        '),
     rtt_off ? rtt_off + ' ROTATE ' : hover('97;107', 'q', " \e[36mROTATE\e[97m "),
     rtt_off ? rtt_off + '        ' : hover('97;107', 'q', '        '),
     ' '*10 + (rrl_off ? rrl_off + ' 🎲 ⥢ ⥤ ' : hover('36;40', 'x', ' 🎲 ⥢ ⥤ ')),
     ' '*10 + (rrl_off ? rrl_off + ' 🎲 ⥣ ⥥ ' : hover('36;47', 'y', ' 🎲 ⥣ ⥥ ')),
     ' '*10 + (rrl_off ? rrl_off + ' 🎲 ⥣ ⥤ ' : hover('36;107', 'w', ' 🎲 ⥣ ⥤ ')),
     ' '*20 + (eat_off ? eat_off + '        ' : hover('30;40', 'e', '        ')),
     ' '*20 + (eat_off ? eat_off + '  EAT!  ' : hover('30;40', 'e', "  #{active}EAT!\e[30m  ")),
     eat_off ? eat_off + '        ' : hover('30;40', 'e', '        '), '']
  end

  def prepare_console_center
    if show_current_land
      column_nums = +" \e[37m"
      x_len.times { |num| column_nums << " #{num+1}  " }
      column_nums = column_nums.center(50)
    else
      column_nums = ' ' * 45
    end
    land_row = 'empty land row'

    [' '*45, column_nums, land_row, land_row, land_row,
     land_row, land_row, land_row, '', '']
  end

  def create_current_land_row
    cur_row = +"\e[37m#{y_len-@land_rows_num}\e[0m"
    cur_row << case @fill_direction
               when '1'
                 place_direction_point(0, (y_len-1))
               when '2'
                 place_direction_point((x_len-1), (y_len-1))
               when '3'
                 place_direction_point(0, 0)
               when '4'
                 place_direction_point((x_len-1), 0)
               end
    cur_row << '| '
    cur_row.center(42 + cur_row.size - x_len*4)
  end

  def place_direction_point(x, y)
    return '|' + color.call if x_len == 1 && y_len == 1
    cur_row = +''
    x_len.times do |col|
      cur_row << if col == x && @land_rows_num == y
                   "|\e[40m___\e[49m"
                 elsif col == 0 && @land_rows_num == (y_len-1)
                   '|' + color.call('_̲1_')
                 elsif col == (x_len-1) && @land_rows_num == (y_len-1)
                   '|' + color.call('_̲2_')
                 elsif col == 0 && @land_rows_num == 0
                   '|' + color.call('_̲3_')
                 elsif col == (x_len-1) && @land_rows_num == 0
                   '|' + color.call('_̲4_')
                 else
                   '|' + color.call
                 end
    end
    cur_row
  end

  def show_player_turn
    @@show_turn = false
    joker_num.size.times do |t|
      @@p_info[p_num][4+t].sub!(/⭑+/, '')
    end
    print "\e[#{36+NS}H\e[9#{p_num}m"
    8.times do |t|
      puts "\e[#{60+WE}C#{@@players_turn[0][t]}#{@@players_turn[p_num][t]}"
    end
  end

  def final_choice
    `pkill -9 -f 'paplay.*krage'`
    spawn("paplay #{KRAGE_DIR}/data/king.ogg")
    display('winer')
    puts "\n\n\n"
    puts "\e[3;9#{p_num}mWe have a Krage King, behold almighty "\
         "#{name.upcase}!!!\e[0;1m\n\n".center(175+WE*2)
    loop do
      print `tput cup #{39+NS}`
      Displayable.write_options(FINAL_OPTIONS)

      key = `#{KRAGE_DIR}/ext/gen_keyboard`
      case key
      when ''
        `pkill -f 'paplay.*king.ogg'`
        if FINAL_OPTIONS[0][5] == '⮕'
          `stty #{STTY_STATE}`
          spawn("paplay --volume=0 #{KRAGE_DIR}/data/echo.ogg")
          print "\ec"
          exec("ruby #{KRAGE_DIR}/krage.rb")
        elsif FINAL_OPTIONS[1][5] == '⮕'
          exit
        end
      when "\e[A", "\e[B"
        Displayable.change_option(FINAL_OPTIONS)
      end
    end
  end

end
