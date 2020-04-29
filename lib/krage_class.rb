# frozen_string_literal: true

require 'displayable'

class Krage

  include Displayable

  @@objects_num = 0
  @@img_thread_num = 0

  attr_accessor :coords, :joker_num, :show_current_land, :eater, :countdown
  attr_reader :name, :p_num, :round, :color, :x_len, :y_len

  def initialize(player)
    @name = player[0].capitalize + player[1..-1]
    @@objects_num += 1
    @p_num = [NUM_OF_PL, @@objects_num].all?(2) ? 4 : @@objects_num
    @round = 0
    @joker_num = [1, 1, 1]
    @joker_timely = @joker_accuracy = 0 if GAME_WITH_TIMER
    @color = proc { |c='___'| "\e[4#{p_num}m#{c}\e[49m" }
    @@p_info[p_num] = [color.call("\e[36m#{name.center(18)}"), '0', '0 ％']
    @@p_info[p_num] += ['3', +'1 ', +'1 ', +'1 ', '', '', 'Rotate']
  end

  def generate_coords
    display
    click = `#{KRAGE_DIR}/ext/gen_click 2> /dev/null`
    if click.size == 1
      click.downcase!
      @@img_info &&= nil if click =~ /(s|g)/
      case click
      when /[rqwesg]/ then click
      when /[1-4]/
        if show_current_land
          spawn("paplay #{KRAGE_DIR}/data/direction.ogg")
          @fill_direction = click
        end
      end
    elsif click.size == 2
      x = click[0].getbyte(0) - WE
      y = click[1].getbyte(0) - NS
      if y == 33
        if x.between?(188, 191)
          exit
        elsif x.between?(184, 185)
          @@music = !@@music
          if @@music then `pkill -CONT -f 'paplay.*krage_'`
          else `pkill -STOP -f 'paplay.*krage_' &`
          end
        elsif x.between?(180, 181)
          @@sfx = !@@sfx
        end
        return
      elsif x.between?(53, 172) && y.between?(35, 64)
        @@img_info &&= nil
        return self.coords = get_map_coords(x, y)
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
    @fill_direction = if GAME_HARD
                        (5-p_num).to_s
                      else
                        p_num.to_s
                      end

    if GAME_WITH_TIMER && round > 1
      spawn("paplay #{KRAGE_DIR}/data/countdown.ogg")
      @timer_start = Time.now
      countdown_timer
      @accuracy = true
    else
      if round == 1
        spawn("paplay #{KRAGE_DIR}/data/correct.ogg")
        assign_land
        @countdown = '' if GAME_WITH_TIMER
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
    set_fill_direction
    if check_place?
      assign_land
      if GAME_WITH_TIMER
        get_joker_timely
        get_joker_accuracy if @accuracy
      end
      true
    else
      get_joker_accuracy(false) if GAME_WITH_TIMER
      show_invalid_land
    end
  end

  def jokers(joker)
    case joker
    when 'q'
      if joker_num[0] > 0
        spawn("paplay #{KRAGE_DIR}/data/rotate.ogg")
        @x_len, @y_len = y_len, x_len
        refresh_jokers(0)
      end
    when 'w'
      if joker_num[1] > 0
        spawn("paplay #{KRAGE_DIR}/data/reroll.ogg")
        if coords&.at(1) == 70
          @x_len = rand(1..6)
        elsif coords&.at(1) == 71
          @y_len = rand(1..6)
        else
          @x_len = rand(1..6)
          @y_len = rand(1..6)
        end
        self.coords = nil
        refresh_jokers(1)
      end
    when 'e'
      unless GAME_HARD && round < 4 || joker_num[2] < 1
        spawn("paplay #{KRAGE_DIR}/data/eat.ogg")
        @eater = true
        refresh_jokers(2)
      end
    end
  end

  def calc_player_territory
    fields_owned = @@map.flatten.count(color.call)
    @@p_info[p_num][1] = fields_owned.to_s
    @@p_info[p_num][2] = "#{(fields_owned/9.0).round(2)} ％"

    bonus = if @@p_info[p_num][9] == 'Rotate' && fields_until_jbonus <= 0
              @@p_info[p_num][9] = 'Reroll'
              add_joker_and_sign(0)
            elsif @@p_info[p_num][9] == 'Reroll' && fields_until_jbonus <= 0
              @@p_info[p_num][9] = 'Eat'
              add_joker_and_sign(1)
            elsif @@p_info[p_num][9] == 'Eat' && fields_until_jbonus <= 0
              @@p_info[p_num][9] = nil
              add_joker_and_sign(2)
            end

    spawn("paplay #{KRAGE_DIR}/data/jsmile.ogg") if bonus
    fields_owned
  end

  def clear_giveuper
    @@p_info.delete(p_num)
  end

  def spawn(*)
    super if @@sfx
  end

  private

  def get_map_coords(x, y)
    x -= 52
    x = x % 4 == 0 ? x / 4 - 1 : x / 4
    y -= 35
    [x, y]
  end

  def coords_to_button
    if valid_button_params?(82, 67)
      'r'
    elsif valid_button_params?(135, 67)
      'q'
    elsif valid_button_params?(145, 70)
      'w'
    elsif valid_button_params?(155, 73)
      'e'
    elsif round > 0 && (@@img_info = click_on_img)
      @@img_thread_num += 1
      Thread.new do
        old_num = @@img_thread_num
        sleep 4
        Thread.exit if @@img_info.nil? || old_num != @@img_thread_num
        @@img_info = nil
        display
      end
    elsif valid_button_params?(72, 70)
      's'
    elsif valid_button_params?(62, 73)
      'g'
    end
  end

  def countdown_timer
    counter = Thread.new { loop { @countdown += ' '; sleep 0.14 } }

    Thread.new do
      rc = "#{33+NS} #{64+WE}"
      until countdown.size > 30
        break unless show_current_land
        print `tput cup #{rc}` + countdown
      end
      Thread.kill(counter)
      if show_current_land then print `tput cup #{rc}` + countdown
      elsif !countdown.empty? then @countdown = ''
      end
      `pkill -f 'paplay.*countdown'`
    end
  end

  def set_fill_direction
    @x, @y = coords
    coords.reverse!
    case @fill_direction
    when '2'
      coords[1] -= x_len - 1
    when '3'
      coords[0] -= y_len - 1
    when '4'
      coords[0] -= y_len - 1
      coords[1] -= x_len - 1
    end
  end

  def check_place?
    x, y = coords
    y_len.times do |row|
      x_len.times do |column|
        return false unless inside_of_map?(x, y, row, column, eater)
      end
    end
    !y_len.times do |row|
      x_len.times do |column|
        if row == 0 && inside_of_map?(x, nil, -1, nil)
          return true if @@map[x-1][y+column] == color.call
        end
        if row == y_len - 1 && inside_of_map?(x, nil, y_len, nil)
          return true if @@map[x+row+1][y+column] == color.call
        end
        if column == 0 && inside_of_map?(nil, y, nil, -1)
          return true if @@map[x+row][y-1] == color.call
        end
        if column == x_len - 1 && inside_of_map?(nil, y, nil, x_len)
          return true if @@map[x+row][y+column+1] == color.call
        end
      end
    end
  end

  def assign_land
    if round == 1
      @show_current_land = false
      x, y = case p_num
             when 1 then GAME_HARD ? [15-y_len, 15-x_len] : [0, 0]
             when 2 then GAME_HARD ? [15-y_len, 15] : [0, 30-x_len]
             when 3 then GAME_HARD ? [15, 15-x_len] : [30-y_len, 0]
             when 4 then GAME_HARD ? [15, 15] : [30-y_len, 30-x_len]
             end
    else
      x, y = coords
    end
    spawn("paplay #{KRAGE_DIR}/data/correct.ogg")
    y_len.times do |row|
      x_len.times { |column| @@map[x+row][y+column] = color.call }
    end
  end

  def show_invalid_land
    spawn("paplay #{KRAGE_DIR}/data/wrong.ogg")
    while [@x, @y].all? { |n| n.between?(0, 29) }
      x, y = coords
      mark = check_place? ? '✔' : 'X'
      y_len.times do |row|
        x_len.times do |column|
          next unless inside_of_map?(x, y, row, column, false)
          @@map[x+row][y+column] = color.call("_̲\e[5m#{mark}\e[25m_")
        end
      end
      display
      clear_invalid_land
      x, y = @x, @y
      until [@x, @y] != [x, y]
        print "\e[?1003h"
        cursor = STDIN.getc
        print "\e[?1003l"
        cursor = STDIN.read_nonblock(5) if cursor == "\e"
        if cursor.size == 1
          cursor.downcase!
          case cursor
          when 's', 'g' then return cursor
          when /[qwe]/ then break jokers(cursor)
          when /[1-4]/
            spawn("paplay #{KRAGE_DIR}/data/direction.ogg")
            break @fill_direction = cursor
          end
        elsif cursor.size == 5
          x = cursor[3].getbyte(0) - WE
          y = cursor[4].getbyte(0) - NS
          x, y = get_map_coords(x, y)
          if cursor[2] == '#'
            self.coords = x, y
            return choose_place
          end
        end
      end
      self.coords = x, y
      set_fill_direction
    end
  end

  def refresh_jokers(reduce_joker=nil)
    joker_num[reduce_joker] -= 1 if reduce_joker
    @@p_info[p_num][3] = joker_num.sum.to_s
    joker_num.each_with_index do |joker, idx|
      @@p_info[p_num][4+idx].sub!(/\d+/, joker.to_s)
    end
  end

  def get_joker_timely
    time = Time.now - @timer_start
    @joker_timely += 1 if time < 4.4
    if @joker_timely > 4
      spawn("paplay #{KRAGE_DIR}/data/jsmile.ogg")
      @joker_timely = 0
      add_joker_and_sign
    end
    @@p_info[p_num][7] = '⏳' * @joker_timely
  end

  def get_joker_accuracy(accuracy=true)
    @accuracy = accuracy
    if accuracy
      spawn("paplay #{KRAGE_DIR}/data/accuracy.ogg")
      @joker_accuracy += 1
    else @joker_accuracy = 0
    end
    if @joker_accuracy > 4
      spawn("paplay #{KRAGE_DIR}/data/jsmile.ogg")
      @joker_accuracy = 0
      add_joker_and_sign
    end
    @@p_info[p_num][8] = '🎯' * @joker_accuracy
  end

  def valid_button_params?(x_min, y_min)
    (0..7) === (coords[0]-x_min) && (0..2) === (coords[1]-y_min)
  end

  def click_on_img
    case coords[0]
    when (40..41) then get_img_info(1, 3)
    when (181..182) then get_img_info(2, 4)
    end
  end

  def get_img_info(upper_player, lower_player)
    case coords[1]
    when 37 then calc_victory(upper_player)
    when 41 then fields_until_jbonus(upper_player)
    when 53 then calc_victory(lower_player)
    when 57 then fields_until_jbonus(lower_player)
    end
  end

  def inside_of_map?(x, y, row, column, eater=true)
    (!x || (x+row).between?(0, 29)) && (!y || (y+column).between?(0, 29)) &&
      (eater || @@map[x+row][y+column] == '___')
  end

  def clear_invalid_land
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
               235 / @@objects_num - fields_owned
             when 'Reroll'
               470 / @@objects_num - fields_owned
             when 'Eat'
               705 / @@objects_num - fields_owned
             end

    if player
      player_name = @@p_info[player][0].gsub(/(\e\[36m| +)/, '')
      return "No more jokers for #{player_name}, enough is enough!" unless fields
      "#{player_name} have to conquer #{fields} "\
      "fields more to gain joker #{next_jbonus}."
    else fields
    end
  end

  def calc_victory(player)
    return unless @@p_info.keys.any?(player)
    players_score = []
    @@p_info.each_value { |ar| players_score << ar[1].to_i }

    empty_spaces = @@map.flatten.count('___')
    selected_pl = @@p_info[player][1].to_i
    strongest = players_score.max
    second_strongest = players_score.max(2)[1]
    player_name = @@p_info[player][0].gsub(/(\e\[36m| +)/, '')

    if strongest != selected_pl
      second_strongest = strongest
      strongest = selected_pl
    end

    fields = 0
    loop do
      fields_left = (empty_spaces-fields) / (players_score.size-HANDICAP)
      break if second_strongest + fields_left < strongest + fields
      fields += 1
    end
    if fields.zero? && player != p_num
      "Do something or #{player_name} will be crowned after this round!"
    elsif fields > empty_spaces
      "Unfortunately, #{player_name} is probably not destined to rule!"
    else
      return "You, #{player_name}, could become the king soon!" if fields.zero?
      "If #{player_name} conquers #{fields} fields in "\
      'this round, he/she could become the Krage King.'
    end
  end

  def add_joker_and_sign(j=nil)
    j ||= rand(3)
    joker_num[j] += 1
    @@p_info[p_num][4+j] << '⭑'
    refresh_jokers
  end

end
