# frozen_string_literal: true
require 'displayable'

class Krage

  include Displayable

  @@objects_num = 0
  @@img_thread_num = 0

  attr_accessor :coords, :joker_num, :show_current_land, :countdown
  attr_reader :name, :p_num, :round, :color, :x_len, :y_len

  def initialize(player)
    @name = player[0].capitalize + player[1..-1]
    @@objects_num += 1
    @p_num = TWO_PL && @@objects_num == 2 ? 4 : @@objects_num
    @round = 0
    @joker_num = [1, 1, 1]
    @joker_time = 0
    @joker_accuracy = 0
    @color = case p_num
             when 1 then proc { |c='___'| "\e[40m#{c}\e[49m" }
             when 2 then proc { |c='___'| "\e[42m#{c}\e[49m" }
             when 3 then proc { |c='___'| "\e[41m#{c}\e[49m" }
             when 4 then proc { |c='___'| "\e[47m#{c}\e[49m" }
             end
    @@p_info[p_num] = [color.call("\e[25m#{name}".center(23)), '0']
    @@p_info[p_num] += ['0 ％', '3', '1', '1', '1', '', '', 'Rotate']
  end

  def generate_coords
    display
    print "\e[?1000h"
    click = `#{KRAGE_DIR}/ext/gen_click 2> /dev/null`
    print "\e[?1000l"
    if click.size == 1
      click.downcase!
      @@img_info &&= nil if click =~ /(s|g)/
      case click
      when /[rqwesg]/ then click
      when /[1-4]/
        if show_current_land
          spawn("paplay #{KRAGE_DIR}/data/direction.ogg")
          @direction = click
        end
      end
    elsif click.size == 2
      x = click[0].getbyte(0)
      y = click[1].getbyte(0)
      if y == 33
        if x.between?(188, 191)
          exit
        elsif x.between?(184, 185)
          @@music = !@@music
          if @@music then `pkill -CONT -f 'paplay.*krage_'`
          else `pkill -STOP -f 'paplay.*krage_' &`
          end
          return
        elsif x.between?(180, 181)
          @@sfx = !@@sfx
          return
        end
      elsif x.between?(53, 172) && y.between?(35, 64)
        @@img_info &&= nil
        return self.coords = map_coords(x, y)
      end
      self.coords = x, y
      coords_to_button
    end
  end

  def roll
    @x_len = rand(1..6)
    @y_len = rand(1..6)
    @round += 1
    @show_current_land = true
    @direction = if @@game_hard
                   case p_num
                   when 1 then '4'
                   when 2 then '3'
                   when 3 then '2'
                   when 4 then '1'
                   end
                 else
                   p_num.to_s
                 end

    if @@game_timer && round > 1
      spawn("paplay #{KRAGE_DIR}/data/countdown.ogg")
      @timer_start = Time.now
      timer_countdown
      @accuracy = true
    else
      if round == 1
        spawn("paplay #{KRAGE_DIR}/data/correct.ogg")
        land_assigner
        @countdown = '' if @@game_timer
        @@show_turn = true
      end
      if x_len + y_len <= 3
        spawn("paplay #{KRAGE_DIR}/data/yousuck.ogg")
      elsif x_len + y_len >= 11
        spawn("paplay #{KRAGE_DIR}/data/evilsmile.ogg")
      else
        spawn("paplay #{KRAGE_DIR}/data/roll.ogg")
      end
    end
  end

  def choose_place
    fill_direction
    if place_check?
      land_assigner
      @eater &&= false
      if @@game_timer
        timer
        accurate if @accuracy
      end
      true
    else
      accurate(false) if @@game_timer
      wrong_place_assigner
    end
  end

  def jokers(joker)
    case joker
    when 'q'
      if joker_num[0] > 0
        spawn("paplay #{KRAGE_DIR}/data/rotate.ogg")
        @x_len, @y_len = y_len, x_len
        joker_refresher(0)
      end
    when 'w'
      if joker_num[1] > 0
        spawn("paplay #{KRAGE_DIR}/data/reroll.ogg")
        if coords&.at(1) == 69
          @x_len = rand(1..6)
        elsif coords&.at(1) == 71
          @y_len = rand(1..6)
        else
          @x_len = rand(1..6)
          @y_len = rand(1..6)
        end
        joker_refresher(1)
      end
    when 'e'
      unless @@game_hard && round < 4 || joker_num[2] < 1
        spawn("paplay #{KRAGE_DIR}/data/eat.ogg")
        @eater = true
        joker_refresher(2)
      end
    end
  end

  def player_territory
    fields_owned = @@map.flatten.count(color.call)
    @@p_info[p_num][1] = fields_owned.to_s
    @@p_info[p_num][2] = "#{(fields_owned/9.0).round(2)} ％"

    bonus = if @@p_info[p_num][9] == 'Rotate' && fields_until_jbonus <= 0
              @@p_info[p_num][9] = 'Reroll'
              joker_num[0] += 1
            elsif @@p_info[p_num][9] == 'Reroll' && fields_until_jbonus <= 0
              @@p_info[p_num][9] = 'Eat'
              joker_num[1] += 1
            elsif @@p_info[p_num][9] == 'Eat' && fields_until_jbonus <= 0
              @@p_info[p_num][9] = nil
              joker_num[2] += 1
            end
    if bonus
      spawn("paplay #{KRAGE_DIR}/data/jsmile.ogg")
      joker_refresher
    end
    fields_owned
  end

  def giveup_cleaner
    @@p_info.delete(p_num)
  end

  def spawn(*)
    super if @@sfx
  end

  private

  def map_coords(x, y)
    x -= 52
    x = x % 4 == 0 ? x / 4 - 1 : x / 4
    y -= 35
    [x, y]
  end

  def coords_to_button
    if buttons_params?(83, 66)
      'r'
    elsif buttons_params?(134, 66)
      'q'
    elsif buttons_params?(144, 69)
      'w'
    elsif buttons_params?(154, 72)
      'e'
    elsif round > 0 && @@img_info = img_params
      @@img_thread_num += 1
      Thread.new do
        old_num = @@img_thread_num
        sleep 3
        Thread.exit if @@img_info.nil? || old_num != @@img_thread_num
        @@img_info = nil
        display
      end
    elsif buttons_params?(73, 69)
      's'
    elsif buttons_params?(63, 72)
      'g'
    end
  end

  def timer_countdown
    counter = Thread.new { loop { @countdown += ' '; sleep 0.14 } }

    Thread.new do
      until countdown.size > 30
        break unless show_current_land
        print `tput cup 33 64` + countdown
      end
      Thread.kill(counter)
      if show_current_land then print `tput cup 33 64` + countdown
      elsif !countdown.empty? then @countdown = ''
      end
      `pkill -f 'paplay.*countdown'`
    end
  end

  def fill_direction
    @x, @y = coords
    coords.reverse!
    case @direction
    when '2'
      coords[1] -= x_len-1
    when '3'
      coords[0] -= y_len-1
    when '4'
      coords[0] -= y_len-1
      coords[1] -= x_len-1
    end
  end

  def place_check?
    x, y = coords
    y_len.times do |row|
      x_len.times do |column|
        return false if outside_of_map?(x, y, row, column)
      end
    end
    y_len.times do |row|
      x_len.times do |column|
        if [0, y_len-1].include?(row)
          unless outside_of_map?(x, nil, -1, nil, nil)
            return true if @@map[x-1][y+column] == color.call
          end
          unless outside_of_map?(x, y, row+1, column, nil)
            return true if @@map[x+row+1][y+column] == color.call
          end
        end
        if [0, x_len-1].include?(column)
          unless outside_of_map?(nil, y, nil, -1, nil)
            return true if @@map[x+row][y-1] == color.call
          end
          unless outside_of_map?(x, y, row, column+1, nil)
            return true if @@map[x+row][y+column+1] == color.call
          end
        end
      end
    end
    false
  end

  def land_assigner
    if round == 1
      @show_current_land = false
      x, y = case p_num
             when 1 then @@game_hard ? [15-y_len, 15-x_len] : [0, 0]
             when 2 then @@game_hard ? [15-y_len, 15] : [0, 30-x_len]
             when 3 then @@game_hard ? [15, 15-x_len] : [30-y_len, 0]
             when 4 then @@game_hard ? [15, 15] : [30-y_len, 30-x_len]
             end
    else
      x, y = coords
    end
    spawn("paplay #{KRAGE_DIR}/data/correct.ogg")
    y_len.times do |row|
      x_len.times { |column| @@map[x+row][y+column] = color.call }
    end
  end

  def wrong_place_assigner
    spawn("paplay #{KRAGE_DIR}/data/wrong.ogg")
    while [@x, @y].all? { |n| n.between?(0, 29) }
      x, y = coords
      mark = place_check? ? '✔' : 'X'
      y_len.times do |row|
        x_len.times do |column|
          next if outside_of_map?(x, y, row, column, true)
          @@map[x+row][y+column] = color.call("_̲\e[5m#{mark}\e[25m_")
        end
      end
      display
      wrong_place_cleaner
      x, y = @x, @y
      until [@x, @y] != [x, y]
        print "\e[?1003h"
        cursor = `#{KRAGE_DIR}/ext/gen_cursor 2>/dev/null`
        print "\e[?1003l"
        if cursor.size == 1
          cursor.downcase!
          case cursor
          when 's', 'g' then return cursor
          when /[qwe]/ then break jokers(cursor)
          when /[1-4]/
            spawn("paplay #{KRAGE_DIR}/data/direction.ogg")
            break @direction = cursor
          end
        elsif cursor.size == 6
          redo unless cursor[0] == "\e"
          x = cursor[4].getbyte(0)
          y = cursor[5].getbyte(0)
          x, y = map_coords(x, y)
          if cursor[3] == '#'
            self.coords = x, y
            return choose_place
          end
        end
      end
      self.coords = x, y
      fill_direction
    end
  end

  def joker_refresher(reduce_joker=nil)
    joker_num[reduce_joker] -= 1 if reduce_joker
    @@p_info[p_num][3] = joker_num.sum.to_s
    joker_num.each_with_index do |n,idx|
      @@p_info[p_num][4+idx] = n.to_s
    end
  end

  def timer
    time = Time.now - @timer_start
    @joker_time += 1 if time < 4.4
    if @joker_time > 4
      spawn("paplay #{KRAGE_DIR}/data/jsmile.ogg")
      @joker_time = 0
      joker_num[rand(3)] += 1
      joker_refresher
    end
    @@p_info[p_num][7] = '⏳' * @joker_time
  end

  def accurate(accuracy=true)
    @accuracy = accuracy
    if accuracy
      spawn("paplay #{KRAGE_DIR}/data/accuracy.ogg")
      @joker_accuracy += 1
    else @joker_accuracy = 0
    end
    if @joker_accuracy > 4
      spawn("paplay #{KRAGE_DIR}/data/jsmile.ogg")
      @joker_accuracy = 0
      joker_num[rand(3)] += 1
      joker_refresher
    end
    @@p_info[p_num][8] = '🎯' * @joker_accuracy
  end

  def buttons_params?(x_min, y_min)
    (0..7) === (coords[0]-x_min) && (0..2) === (coords[1]-y_min)
  end

  def img_params
    case coords[0]
    when (40..41) then img_rows(1, 3)
    when (181..182) then img_rows(2, 4)
    end
  end

  def img_rows(pl1, pl2)
    case coords[1]
    when 37 then win_calc(pl1)
    when 41 then fields_until_jbonus(pl1)
    when 53 then win_calc(pl2)
    when 57 then fields_until_jbonus(pl2)
    end
  end

  def outside_of_map? (x, y, row, column, not_eater = !@eater)
    x && !(x+row).between?(0,29) || y && !(y+column).between?(0,29) ||
      not_eater && @@map[x+row][y+column] != '___'
  end

  def wrong_place_cleaner
    @@map.each do |row|
      row.map! do |point|
        point =~ /(X|✔)/ ? '___' : point
      end
    end
  end

  def fields_until_jbonus(player=nil)
    next_jbonus = @@p_info[player||p_num][9] rescue return
    fields_owned = @@p_info[player||p_num][1].to_i
    fields = case next_jbonus
             when 'Rotate'
               235/@@objects_num - fields_owned
             when 'Reroll'
               470/@@objects_num - fields_owned
             when 'Eat'
               705/@@objects_num - fields_owned
             end

    if player
      player_name = @@p_info[player][0].gsub(/( .+25m| +)/, '')
      return "No more jokers for #{player_name}, enough is enough!" unless fields
      "#{player_name} have to conquer #{fields} "\
      "fields more to gain joker #{next_jbonus}."
    else fields
    end
  end

  def win_calc(player)
    players_score = []
    pl_idx = @@p_info.keys.index(player)
    return unless pl_idx
    @@p_info.values.each { |ar| players_score << ar[1].to_i }

    empty_spaces = @@map.flatten.count('___')
    current_pl = players_score[pl_idx]
    strongest = players_score.max
    second_strongest = players_score.max(2)[1]
    player_name = @@p_info[player][0].gsub(/( .+25m| +)/, '')

    if strongest != current_pl
      second_strongest = strongest
      strongest = current_pl
    end

    fields = 0
    loop do
      fields_to_catch_up = (empty_spaces-fields) / (players_score.size-HANDICAP)
      break if second_strongest + fields_to_catch_up < strongest + fields
      fields += 1
    end
    if fields.zero? && player != p_num
      return "Do something or #{player_name} will be crowned after this round!"
    end
    "If #{player_name} can conquer #{fields} fields more"\
    ' until the end of this round, he could be crowned.'
  end

end
