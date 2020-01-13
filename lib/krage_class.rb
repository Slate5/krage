require 'displayable'

class Krage

  include Displayable

  @@objects_num = 0

  @@map_params = proc { |n| n.between?(0, 29) }

  @@limit_img_thread = false

  attr_accessor :coords, :joker_num, :show_current_land, :countdown

  attr_reader :name, :x_len, :y_len, :round, :color, :p_num

  def initialize(player)
    @name = player[0].capitalize + player[1..-1]
    @@objects_num += 1
    @p_num = @@objects_num
    @round = 0
    @joker_num = [1, 1, 1]
    @joker_bonus = %w(Rotate Reroll Eat)
    @joker_time = 0
    @joker_accuracy = 0
    case p_num
    when 1 then @color = proc { |c='___'| "\e[40m#{c}\e[49m" }
    when 2 then @color = proc { |c='___'| "\e[47m#{c}\e[49m" }
    when 3 then @color = proc { |c='___'| "\e[42m#{c}\e[49m" }
    when 4 then @color = proc { |c='___'| "\e[41m#{c}\e[49m" }
    end
    @@p_info[p_num] = [color.call("\e[25m#{name}".center(23))]
    @@p_info[p_num] += ['0', '0 ％', '3', '1', '1', '1', '', '']
  end

  def generate_coords
    display
    self.coords = nil
    print "\e[?1000h"
    click = `#{KRAGE_DIR}/ext/gen_click 2> /dev/null`
    print "\e[?1000l"
    if click.size == 1
      @img_info = nil if click =~ /(s|g)/
      case click = click.downcase
      when 'r' then 'roll'
      when 's' then 'skip'
      when 'g' then 'giveup'
      when /[qwe]/ then click
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
          `pkill -STOP -f 'paplay.*krage_' &` if @@music
          `pkill -CONT -f 'paplay.*krage_'` unless @@music
          @@music = !@@music
        elsif x.between?(180, 181)
          @@sfx = !@@sfx
        end
      elsif x.between?(53, 172) && y.between?(35, 64)
        x, y = map_coords(x, y)
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
    @direction = p_num.to_s
    if round == 1
      spawn("paplay #{KRAGE_DIR}/data/correct.ogg")
      land_assigner
    end
    if @@game_with_timer
      spawn("paplay #{KRAGE_DIR}/data/countdown.ogg") if round > 1
      @start_timer = Time.now
      @countdown = ''
      @timer_on = true
      @accuracy = true
    else
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
    return unless coords&.all?(&@@map_params)
    map_fill_direction
    if place_check?
      land_assigner
      @eater = false if @eater
      if @@game_with_timer
        timer
        accurate if @accuracy
      end
      true
    else
      accurate(false) if @@game_with_timer
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
      if joker_num[2] > 0
        spawn("paplay #{KRAGE_DIR}/data/eat.ogg")
        @eater = true
        joker_refresher(2)
      end
    end
  end

  def player_territory
    @fields_owned = @@map.flatten.count(color.call)

    bonus = if @joker_bonus[0] && fields_until_jbonus <= 0
              @joker_bonus[0] = nil
              joker_num[0] += 1
            elsif @joker_bonus[1] && fields_until_jbonus <= 0
              @joker_bonus[1] = nil
              joker_num[1] += 1
            elsif @joker_bonus[2] && fields_until_jbonus <= 0
              @joker_bonus[2] = nil
              joker_num[2] += 1
            end
    if bonus
      spawn("paplay #{KRAGE_DIR}/data/jsmile.ogg")
      joker_refresher
    end
    @@p_info[p_num][1] = @fields_owned.to_s
    @@p_info[p_num][2] = "#{(@fields_owned/9.0).round(2)} ％"
    @fields_owned
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
      'roll'
    elsif buttons_params?(134, 66)
      'q'
    elsif buttons_params?(144, 69)
      'w'
    elsif buttons_params?(154, 72)
      'e'
    elsif round > 0 && @img_info = img_params
      Thread.new do
        Thread.exit if @@limit_img_thread
        @@limit_img_thread = true
        sleep 3
        @@limit_img_thread = false
        Thread.exit if @img_info.nil?
        @img_info = nil
        display
      end
    elsif buttons_params?(73, 69)
      'skip'
    elsif buttons_params?(63, 72)
      'giveup'
    end
  end

  def buttons_params?(x_min, y_min)
    (0..7) === (coords[0]-x_min) && (0..2) === (coords[1]-y_min)
  end

  def img_params
    case p_num
    when 1
      if coords[0].between?(40, 41)
        if coords[1] == 37
          img = 'fields'
        elsif coords[1] == 41
          img = 'jokers'
        end
      end
    when 2
      if coords[0].between?(181, 182)
        if coords[1] == 53
          img = 'fields'
        elsif coords[1] == 57
          img = 'jokers'
        end
      end
    when 3
      if coords[0].between?(181, 182)
        if coords[1] == 37
          img = 'fields'
        elsif coords[1] == 41
          img = 'jokers'
        end
      end
    when 4
      if coords[0].between?(40, 41)
        if coords[1] == 53
          img = 'fields'
        elsif coords[1] == 57
          img = 'jokers'
        end
      end
    end
    if img == 'fields'
      'You could be crowned until the end of this round. '\
      "Conquer #{color.call(win_calc)} fields more! If possible..."
    elsif img == 'jokers'
      num = fields_until_jbonus
      return "No more jokers #{color.call(name)}, enough is enough!" unless num
      "You have to conquer #{color.call(num)} fields "\
      "more to gain joker #{@joker_bonus.compact.first}."
    end
  end

  def win_calc
    players_score = []
    pl_idx = @@p_info.keys.index(p_num)
    @@p_info.values.each { |ar| players_score << ar[1].to_i }
    
    empty_spaces = @@map.flatten.count('___')
    current_pl = players_score[pl_idx]
    strongest = players_score.max
    second_strongest = players_score.max(2)[1]

    if strongest != current_pl
      second_strongest = strongest
      strongest = current_pl
    end

    fields = 0
    win = false
    until win
      fields += 1
      empty_fields_to_catch_up = (empty_spaces-fields) / (players_score.size-0.75)
      win = second_strongest + empty_fields_to_catch_up < strongest + fields
    end
    fields   
  end

  def fields_until_jbonus
    bonus_left = @joker_bonus.compact.size
    case bonus_left
    when 3
      280/@@objects_num - @fields_owned
    when 2
      540/@@objects_num - @fields_owned
    when 1
      700/@@objects_num - @fields_owned
    end
  end

  def map_fill_direction
    @x, @y = coords
    coords.reverse!
    case @direction
    when '2'
      coords[0] -= y_len-1
      coords[1] -= x_len-1
    when '3'
      coords[1] -= x_len-1
    when '4'
      coords[0] -= y_len-1
    end
  end

  def land_assigner
    if round == 1
      @show_current_land = false
      case p_num
      when 1 then x, y = 0, 0
      when 2 then x, y = 30-y_len, 30-x_len
      when 3 then x, y = 0, 30-x_len
      when 4 then x, y = 30-y_len, 0
      end
    else
      x, y = coords
    end
    spawn("paplay #{KRAGE_DIR}/data/correct.ogg")
    y_len.times do |row|
      x_len.times { |point| @@map[x+row][y+point] = color.call }
    end
  end

  def place_check?
    x, y = coords
    y_len.times do |row|
      x_len.times do |point|
        return false if outside_of_map?(x, y, row, point)
      end
    end
    y_len.times do |row|
      x_len.times do |point|
        if [0, y_len-1].include?(row)
          unless outside_of_map?(x, nil, -1, nil, nil)
            return true if @@map[x-1][y+point] == color.call
          end
          unless outside_of_map?(x, y, row+1, point, nil)
            return true if @@map[x+row+1][y+point] == color.call
          end
        end
        if [0, x_len-1].include?(point)
          unless outside_of_map?(nil, y, nil, -1, nil)
            return true if @@map[x+row][y-1] == color.call
          end
          unless outside_of_map?(x, y, row, point+1, nil)
            return true if @@map[x+row][y+point+1] == color.call
          end
        end
      end
    end
    false
  end

  def outside_of_map? (x, y, row, point, not_eater = !@eater)
    x && !(x+row).between?(0,29) || y && !(y+point).between?(0,29) ||
      not_eater && @@map[x+row][y+point] != '___'
  end

  def wrong_place_assigner
    spawn("paplay #{KRAGE_DIR}/data/wrong.ogg") if [@x,@y].all?(&@@map_params)
    while [@x,@y].all?(&@@map_params)
      x, y = coords
      mark = place_check? ? '✔' : 'X'
      y_len.times do |row|
        x_len.times do |point|
          next if outside_of_map?(x, y, row, point, true)
          @@map[x+row][y+point] = color.call("_̲\e[5m#{mark}\e[25m_")
        end
      end
      display
      wrong_place_reset
      x, y = @x, @y
      until [@x,@y] != [x,y]
        print "\e[?1003h"
        cursor = `#{KRAGE_DIR}/ext/gen_cursor 2>/dev/null`
        print "\e[?1003l"
        if cursor.size == 1
          case cursor = cursor.downcase
          when 's' then return 'skip'
          when 'g' then return 'giveup'
          when /[qwe]/ then break jokers(cursor)
          when /[1-4]/
            spawn("paplay #{KRAGE_DIR}/data/direction.ogg")
            break @direction = cursor
          end
        elsif cursor.size > 5
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
      map_fill_direction
    end
  end

  def wrong_place_reset
    @@map.each do |row|
      row.map! do |point|
        point =~ /(X|✔)/ ? '___' : point
      end
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
    time = Time.now - @start_timer
    @joker_time += 1 if time < 4.4
    if @joker_time > 4
      spawn("paplay #{KRAGE_DIR}/data/jsmile.ogg")
      @joker_time = 0
      joker_num[rand(3)] += 1
      joker_refresher
    end
    @@p_info[p_num][7] = '⌛' * @joker_time
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

end
