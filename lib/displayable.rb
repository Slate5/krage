# frozen_string_literal: true
require 'yaml'

module Displayable

  KRAGE_DIR = File.dirname(__dir__)

  @@map = Array.new(30) { Array.new(30) { '___' } }

  @@game_timer = false
  @@game_hard = false
  HANDICAP = @game_hard ? 0.5 : 0.7

  @@p_info = {}

  @@music = true
  @@sfx = true
  @@music_old = false
  @@show_turn = true

  @@stubs = { 2 => " \e[1;33mFields\e[34m🗺  ",
              4 => " \e[1;33mPercent:\e[34m ",
              6 => " \e[1;33mJokers\e[34m🃏 ",
              8 => "  \e[1;35mROTATE\e[34m  ",
              9 => "  \e[1;35mREROLL\e[34m  ",
             10 => "  \e[1;35mEAT\e[34m     ",
             12 => " \e[1;33mTimely:\e[34m  ",
             13 => " \e[1;33mAccuracy:\e[34m"}

  @@time_stubs = ->(n) { @@game_timer && [12,13,28,29].include?(n) }

  LOADING = %w(🕧 🕘 🕛 ⏸️\ )
  SPACE = ' '*18
  HID = "\e[8;0;8;1m"
  B_W = "30;107m"

  @@left_bird = YAML.load(File.read("#{KRAGE_DIR}/ext/left_bird.yaml"))
  @@right_bird = YAML.load(File.read("#{KRAGE_DIR}/ext/right_bird.yaml"))
  @@players_turn = YAML.load(File.read("#{KRAGE_DIR}/ext/players_turn.yaml"))

  def display(winer=nil)
    @@display_str = +''
    @land_rows_num = y_len
    if @@music != @@music_old
      @@music_old = @@music
      @@music_icon = @@music ? '🎶' : '🕒'
      unless @@music
        Thread.new do
          LOADING.each do |icon|
            4.times { sleep 0.12; Thread.exit if @@music }
            @@music_icon = icon
            print `tput cup 0 151` + icon
          end
        end
      end
    end
    sfx_icon = @@sfx ? '🔊' : '🔇'
    map_border = "#{SPACE}\e[36;44m#{'KRAGE'.center(123)}\e[0m#{SPACE}\n"
    @@display_str << ' '*147 + "#{sfx_icon}  #{@@music_icon}  \e[40m ❌ \e[0m\n"
    @@display_str << map_border
    map_row_each
    @@display_str << map_border
    return (print `clear` + @@display_str) if winer

    console_rows = [@@left_bird, buttons('left'), current_land_rows,
                    buttons('right'), @@right_bird].transpose.flatten

    console_rows.each do |row|
      if show_current_land
        if @land_rows_num > 0 && row == 'empty land row'
          @land_rows_num -= 1
          row = current_land_row.center(x_len*10+51)
        elsif row == 'empty land row'
          row = ' '*42
        end
      elsif row == 'empty land row'
        row = ' '*42
      end
      @@display_str << row
    end
    print `tput cup 0 0` + @@display_str
    show_player_turn if @@show_turn
  end

  def map_row_each
    @@map.each_with_index do |row, num|
      case num
      when 0 then map_row(row, 1, 2, 0)
      when 2, 4, 6 then map_row(row, 1, 2, num/2, @@stubs[num])
      when 8, 9, 10 then map_row(row, 1, 2, num-4, @@stubs[num])
      when 16 then map_row(row, 3, 4, 0)
      when 18, 20, 22 then map_row(row, 3, 4, num/2-8, @@stubs[num-16])
      when 24, 25, 26 then map_row(row, 3, 4, num-20, @@stubs[num-16])
      when @@time_stubs
        case num
        when 12, 13
          map_row(row, 1, 2, num-5, @@stubs[num])
        when 28, 29
          map_row(row, 3, 4, num-21, @@stubs[num-16])
        end
      else map_row(row)
      end
    end
  end

  def map_row(row, left_pl=0, right_pl=0, info=0, stub='')
    reduce = info.between?(2,3) ? 1 : 0
    left_table, right_table = SPACE, SPACE
    unless @@p_info[left_pl].nil?
      reduce = @@p_info[left_pl][info].size if [7, 8].include?(info)
      left_table = (stub + @@p_info[left_pl][info]).ljust(30-reduce)
    end
    unless @@p_info[right_pl].nil?
      reduce = @@p_info[right_pl][info].size if [7, 8].include?(info)
      right_table = (stub + @@p_info[right_pl][info]).ljust(30-reduce)
    end
    if info.zero?
      if p_num == left_pl
        left_table[5..6] = "\e[5m👉"; left_table[-7..-6] = "\e[5m👈"
      elsif p_num == right_pl
        right_table[5..6] = "\e[5m👉"; right_table[-7..-6] = "\e[5m👈"
      end
    end
    @@display_str << left_table + "\e[44m  \e[0m"
    row.each_with_index do |point,idx|
      @@display_str << '|' if idx > 0
      @@display_str << point
    end
    @@display_str << "\e[44m  \e[0m" + right_table + "\n"
  end

  def buttons(side)
    available1 = "\e[45m" if show_current_land
    available2 = "\e[45m" unless show_current_land
    j1 = joker_num[0].zero? ? HID : available2
    j2 = joker_num[1].zero? ? HID : available2
    j3 = joker_num[2].zero? ? HID : available2
    j3 = "\e[45m" if @@game_hard && round < 4
    info = if round < 1
             'First roll will place a land in your corner'\
             " of the map, ROLL #{color.call(name)}!"
           elsif show_current_land
             "Now #{color.call(name)}, place your "\
             'land on the map or use joker if any!'
           else
             "It is your turn #{color.call(name)}, ROLL!"
           end
    left_buttons = ["#{available1}|      |\e[0m|",
                    "#{available1}| ROLL |\e[0m|",
                    "#{available1}|      |\e[0m|",
                    "#{available2}        \e[0m#{' '*11}",
                    "#{available2}  SKIP  \e[0m#{' '*11}",
                    "#{available2}        \e[0m#{' '*11}",
                    "#{available2}        \e[0m#{' '*21}",
                    "#{available2} GIVEUP \e[0m#{' '*21}",
                    "#{available2}        \e[0m#{' '*83}",
                    "INFO: \e[1;35m#{@img_info||info} \e[30m==".center(137,'='),
                    '']

    right_buttons = ["\e[#{B_W}#{j1}    \e[7m#{j1}    ",
                     "\e[#{B_W}#{j1} ROT\e[7m#{j1}ATE ",
                     "\e[#{B_W}#{j1}    \e[7m#{j1}    ",
                     "#{' '*10}\e[7;#{B_W}#{j2} 🎲  ➡  ",
                     "#{' '*10}\e[#{B_W}#{j2} 🎲  ⬆➡ ",
                     "#{' '*10}\e[7;#{B_W}#{j2} 🎲  ⬆  ",
                     "#{' '*20}\e[40m#{j3}        ",
                     "#{' '*20}\e[1;31;40m#{j3}  EAT!  ",
                     "\e[40m#{j3}        ", '', '']

    side == 'left' ? left_buttons : right_buttons
  end

  def current_land_rows
    timer = @@game_timer ? display_timer : ' '*42
    if show_current_land
      nums = +"\e[33m"
      x_len.times { |n| nums << " #{n+1}  " }
      land_num = nums.center(47)
    else
      land_num = ' '*42
    end
    land_row = 'empty land row'

    [timer, land_num, land_row, land_row, land_row,
     land_row, land_row, land_row, '', '', '']
  end

  def current_land_row
    cur_row = +"\e[33m#{y_len-@land_rows_num}\e[0m"
    cur_row << case @direction
               when '1'
                 show_direction_point(0, (y_len-1))
               when '2'
                 show_direction_point((x_len-1), (y_len-1))
               when '3'
                 show_direction_point(0, 0)
               when '4'
                 show_direction_point((x_len-1), 0)
               end
    cur_row << '| '
  end

  def show_direction_point(x, y)
    return "|#{color.call}" if x_len == 1 && y_len == 1
    cur_row = +''
    x_len.times do |c|
      cur_row << if c == x && @land_rows_num == y
                   "|\e[44m___\e[49m"
                 else
                   if c.zero? && @land_rows_num == (y_len-1)
                     "|#{color.call('_1_')}"
                   elsif c == (x_len-1) && @land_rows_num.zero?
                     "|#{color.call('_4_')}"
                   elsif c == (x_len-1) && @land_rows_num == (y_len-1)
                     "|#{color.call('_2_')}"
                   elsif c.zero? && @land_rows_num.zero?
                     "|#{color.call('_3_')}"
                   else
                     "|#{color.call}"
                   end
                 end
    end
    cur_row
  end

  def display_timer
    green = 180
    red = 7
    timer_str = +'   ⏳'
    31.times do |t|
      if @countdown&.size&.<= t
        timer_str << "\e[48;2;#{red};#{green};0m "
      else timer_str << ' '
      end
      green -= 5
      red += 8
    end
    timer_str << "\e[0m⌛    "
  end

  def show_player_turn
    @@show_turn = false
    print "\e[#{color.call[2..3].to_i-10}m"
    8.times do |t|
      print "#{`tput cup #{34+t} 60`}#{@@players_turn[0][t]}"\
            "#{@@players_turn[p_num][t]}"
    end
  end

end
