# frozen_string_literal: true

require 'yaml'

module Displayable

  @@map = Array.new(30) { Array.new(30) { '___' } }

  @@p_info = {}

  @@music = @@sfx = SILENT ? false : true
  @@music_icon = '⏸️ ' if SILENT
  @@previous_music_status = false
  @@show_turn = true
  @@img_info = nil

  STUBS = { 2 => "\e[95;45m Fields\e[37m\e]8;;More Info\e\\📖\e]8;;\e\\ ",
            4 => "\e[95;45m Percent:\e[37m ",
            6 => "\e[95;45m Jokers\e[37m\e]8;;More Info\e\\📖\e]8;;\e\\ ",
            8 => "\e[95;45m  ROTATE\e[37m  ",
            9 => "\e[95;45m  REROLL\e[37m  ",
            10 => "\e[95;45m  EAT\e[37m     ",
            12 => "\e[95;45m Timely:\e[37m  ",
            13 => "\e[95;45m Accuracy:\e[37m" }.freeze

  CHK_TIMER_STUBS = ->(n) { GAME_WITH_TIMER && [12, 13, 28, 29].include?(n) }

  LOADING = %w(🕧 🕘 🕛 ⏸️\ ).freeze
  SPACE = ' ' * 18
  HID = "\e[8;0;8;1m"

  @@left_bird = YAML.load(File.read("#{KRAGE_DIR}/ext/left_bird.yaml"))
  @@right_bird = YAML.load(File.read("#{KRAGE_DIR}/ext/right_bird.yaml"))
  @@players_turn = YAML.load(File.read("#{KRAGE_DIR}/ext/players_turn.yaml"))

  def self.indent(string=@@display_str)
    WE.zero? ? string : "\e[#{WE}C" + string.gsub(/\n/, "\n\e[#{WE}C")
  end

  def display(winer=nil)
    @@display_str = +''
    @land_rows_num = y_len
    if @@music != @@previous_music_status
      @@previous_music_status = @@music
      @@music_icon = @@music ? '🎶' : '🕒'
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
    sfx_icon = @@sfx ? '🔊' : '🔇'
    map_border = "#{SPACE}\e[36;40m#{'KRAGE'.center(123)}\e[0m#{SPACE}\n"
    @@display_str << "#{' '*147}#{sfx_icon}  #{@@music_icon}  \e[40m ❌ \e[0m\n"
    @@display_str << map_border
    shovel_map_lines
    @@display_str << map_border
    return (print `clear && tput cup #{NS}` + Displayable.indent) if winer
    @@display_str << (GAME_WITH_TIMER ? display_timer : "\n")

    console_rows = [@@left_bird, construct_left_buttons, prepare_console_center,
                    construct_right_buttons, @@right_bird].transpose.flatten

    console_rows.each do |row_element|
      if show_current_land
        if @land_rows_num > 0 && row_element == 'empty land row'
          @land_rows_num -= 1
          row_element = create_current_land_row.center(x_len*10+53)
        elsif row_element == 'empty land row'
          row_element = ' ' * 44
        end
      elsif row_element == 'empty land row'
        row_element = ' ' * 44
      end
      @@display_str << row_element
    end
    print `tput cup #{NS}` + Displayable.indent
    show_player_turn if @@show_turn
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
      left_table_line = "\e[45m#{SPACE}" if @@p_info[1]
      right_table_line = "\e[45m#{SPACE}" if @@p_info[2]
    elsif line.between?(17, 27)
      left_table_line = "\e[45m#{SPACE}" if @@p_info[3]
      right_table_line = "\e[45m#{SPACE}" if @@p_info[4]
    end

    left_table_line ||= SPACE
    right_table_line ||= SPACE

    @@display_str << "#{left_table_line}\e[40m  \e[0m"
    @@map[line].each_with_index do |point, idx|
      @@display_str << (idx > 0 ? "|#{point}" : point)
    end
    @@display_str << "\e[40m  \e[0m#{right_table_line}\e[0m\n"
  end

  def construct_table_line(player_side, info, stub)
    if info.zero?
      if p_num == player_side
        color.call("\e[5m👉\e[25m#{name.center(14)}\e[5m👈")
      else @@p_info[player_side][0]
      end
    else
      reduce_ljust = case info
                     when 1, 3 then 22
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
    timer_str << "\e[0m⌛\n"
  end

  def construct_left_buttons
    show_current_land ? unavailable1 = "\e[45m" : unavailable2 = "\e[45m"
    default_info = if round < 1
                     'First roll will place a land in your corner'\
                     " of the map, ROLL #{color.call(name)}!"
                   elsif show_current_land
                     "Now #{color.call(name)}, place your "\
                     'land on the map or use joker if any!'
                   else
                     "It is your turn #{color.call(name)}, ROLL!"
                   end

    ["#{unavailable1}|      |\e[0m|",
     "#{unavailable1}| ROLL |\e[0m|",
     "#{unavailable1}|      |\e[0m|",
     "#{unavailable2}        \e[0m#{' '*11}",
     "#{unavailable2}  SKIP  \e[0m#{' '*11}",
     "#{unavailable2}        \e[0m#{' '*11}",
     "#{unavailable2}        \e[0m#{' '*21}",
     "#{unavailable2} GIVEUP \e[0m#{' '*21}",
     "#{unavailable2}        \e[0m#{' '*85}",
     "INFO: \e[37m#{@@img_info||default_info} \e[30m=".center(137, '=')]
  end

  def construct_right_buttons
    unavailable = "\e[45m" unless show_current_land
    rtt_color = joker_num[0].zero? ? HID : "\e[36;107m#{unavailable}"
    rrl_color = joker_num[1].zero? ? HID : unavailable
    eat_color = joker_num[2].zero? ? HID : "\e[40m#{unavailable}"
    eat_color = "\e[45m" if GAME_HARD && round < 4
    active = @eater ? "\e[32m" : "\e[36m"

    ["#{rtt_color}        ",
     "#{rtt_color} ROTATE ",
     "#{rtt_color}        ",
     "#{' '*10}\e[36;40m#{rrl_color} 🎲 ⥢ ⥤ ",
     "#{' '*10}\e[36;47m#{rrl_color} 🎲 ⥣ ⥥ ",
     "#{' '*10}\e[36;107m#{rrl_color} 🎲 ⥣ ⥤ ",
     "#{' '*20}#{eat_color}        ",
     "#{' '*20}#{active}#{eat_color}  EAT!  ",
     "#{eat_color}        ", '']
  end

  def prepare_console_center
    if show_current_land
      column_nums = +"\e[37m"
      x_len.times { |num| column_nums << " #{num+1}  " }
      column_nums = column_nums.center(49)
    else
      column_nums = ' ' * 44
    end
    land_row = 'empty land row'

    [' '*44, column_nums, land_row, land_row, land_row,
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
  end

  def place_direction_point(x, y)
    return "|#{color.call}" if x_len == 1 && y_len == 1
    cur_row = +''
    x_len.times do |col|
      cur_row << if col == x && @land_rows_num == y
                   "|\e[40m___\e[49m"
                 elsif col.zero? && @land_rows_num == (y_len-1)
                   "|#{color.call('_1_')}"
                 elsif col == (x_len-1) && @land_rows_num == (y_len-1)
                   "|#{color.call('_2_')}"
                 elsif col.zero? && @land_rows_num.zero?
                   "|#{color.call('_3_')}"
                 elsif col == (x_len-1) && @land_rows_num.zero?
                   "|#{color.call('_4_')}"
                 else
                   "|#{color.call}"
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

end
