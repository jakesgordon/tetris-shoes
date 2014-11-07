require 'shoes'

#===============
# Game Constants
#===============

WIDTH  = 300            # width of tetris court (in pixels)
HEIGHT = 600            # height of tetris court (in pixels)
NX     = 10             # width of tetris court (in blocks)
NY     = 20             # height of tetris court (in blocks)
DX     = WIDTH / NX     # pixel width of a single tetris block
DY     = HEIGHT / NY    # pixel height of a single tetris block
FPS    = 60
PACE   = { :start => 0.5, :decrement => 0.005, :min => 0.1 } # how long before a piece drops by 1 row (seconds)

#==============
# Tetris Pieces
#==============
#
# blocks: each element represents a rotation of the piece (0, 90, 180, 270)
#         each element is a 16 bit integer where the 16 bits represent
#         a 4x4 set of blocks, e.g. j.blocks[0] = 0x44C0
#
#             0100 = 0x4 << 3 = 0x4000
#             0100 = 0x4 << 2 = 0x0400
#             1100 = 0xC << 1 = 0x00C0
#             0000 = 0x0 << 0 = 0x0000
#                               ------
#                               0x44C0
#

I = { size: 4, blocks: {:up => 0x0F00, :right => 0x2222, :down => 0x00F0, :left => 0x4444}, color: '#00FFFF' };
J = { size: 3, blocks: {:up => 0x44C0, :right => 0x8E00, :down => 0x6440, :left => 0x0E20}, color: '#0000FF' };
L = { size: 3, blocks: {:up => 0x4460, :right => 0x0E80, :down => 0xC440, :left => 0x2E00}, color: '#FF8000' };
O = { size: 2, blocks: {:up => 0xCC00, :right => 0xCC00, :down => 0xCC00, :left => 0xCC00}, color: '#FFFF00' };
S = { size: 3, blocks: {:up => 0x06C0, :right => 0x8C40, :down => 0x6C00, :left => 0x4620}, color: '#00FF00' };
T = { size: 3, blocks: {:up => 0x0E40, :right => 0x4C40, :down => 0x4E00, :left => 0x4640}, color: '#8040FF' };
Z = { size: 3, blocks: {:up => 0x0C60, :right => 0x4C80, :down => 0xC600, :left => 0x2640}, color: '#FF0000' };

#============
# Game Runner
#============
class Tetris

  class Piece

    attr :type, :dir, :x, :y

    def initialize(type, x = nil, y = nil, dir = nil)
      @type = type
      @dir  = dir || :up
      @x    = x   || rand(NX - type[:size])
      @y    = y   || 0
    end

    def rotate
      newdir = case dir
               when :left  then :up
               when :up    then :right
               when :right then :down
               when :down  then :left
               end
      Piece.new(type, x, y, newdir)
    end

    def move(dir)
      case dir
      when :right then Piece.new(type, x + 1, y,     @dir)
      when :left  then Piece.new(type, x - 1, y,     @dir)
      when :down  then Piece.new(type, x,     y + 1, @dir)
      end
    end

    def each_occupied_block
      bit = 0b1000000000000000
      row = 0
      col = 0
      blocks = type[:blocks][dir]
      until bit.zero?
        if (blocks & bit) == bit
          yield x+col, y+row
        end
        col = col + 1
        if col == 4
          col = 0
          row = row + 1
        end
        bit = bit >> 1
      end
    end

  end

  attr :dt, :score, :vscore, :lost, :pace, :blocks, :actions, :bag, :current

  def initialize
    @dt      = 0                 # time since game started
    @score   = 0                 # the current score
    @vscore  = 0                 # the rendered score (make it play catch-up like a slot machine)
    @pace    = PACE[:start]      # how long before the current piece drops by 1 row
    @blocks  = Array.new(NX){[]} # 2 dimensional array (NX * NY) representing tetris court - either empty block or occupied by a 'piece'
    @actions = []                # queue of user inputs
    @bag     = [];               # a collection of random pieces to be used
    @current = random_piece      # the current piece
  end

  def update(seconds)
    handle(actions.shift)
    @dt += seconds
    if dt > pace
      @dt = dt - pace
      drop
    end
    update_score
  end

  def drop
    if !move(:down)
      add_score(10)
      drop_piece
      remove_lines
      actions.clear
      lose if occupied(current)
    end
  end

  def move(dir)
    nextup = current.move(dir)
    if unoccupied(nextup)
      @current = nextup
      true
    end
  end

  def rotate
    nextup = current.rotate
    if unoccupied(nextup)
      @current = nextup
      true
    end
  end

  def unoccupied(piece)
    !occupied(piece)
  end

  def occupied(piece)
    result = false
    piece.each_occupied_block do |x,y|
      if ((x < 0) || (x >= NX) || (y < 0) || (y >= NY) || blocks[x][y])
        result = true
      end
    end
    result
  end

  def drop_piece
    current.each_occupied_block { |x,y| blocks[x][y] = current.type }
    @current = random_piece
  end

  def remove_lines
    lines_removed = 0
    NY.times do |y|
      complete = true
      NX.times do |x|
        complete = false if blocks[x][y].nil?
      end
      if complete
        remove_line(y)
        lines_removed += 1
      end
    end
    if lines_removed > 0
      add_score(100 * 2**(lines_removed-1))  # 1: 100, 2: 200, 3: 400, 4: 800, etc
      increase_pace(lines_removed)
    end
  end

  def remove_line(n)
    n.downto(0) do |y|
      NX.times do |x|
        blocks[x][y] = y.zero? ? nil : blocks[x][y-1]
      end
    end
  end

  def add_score(n)
    @score += n
  end

  def update_score
    catchup = score - vscore
    @vscore += case
               when catchup > 100 then 10
               when catchup > 50  then 5
               when catchup > 0   then 1
               else
                 0
               end
  end

  def lose
    @lost = true
  end

  def increase_pace(multiplier)
    # @pace = [pace - multiplier*SPEED[:decrement], SPEED[:min]].max
  end

  def lost?
    !!@lost
  end

  def handle(action)
    case action
    when :left   then move(:left)
    when :right  then move(:right)
    when :rotate then rotate
    when :drop   then drop
    end
  end

  def random_piece
    if bag.empty?
      bag = [I,I,I,I,J,J,J,J,L,L,L,L,O,O,O,O,S,S,S,S,T,T,T,T,Z,Z,Z,Z].shuffle
    end
    Piece.new(bag.pop)
  end

  def each_occupied_block
    NY.times do |y|
      NX.times do |x|
        unless blocks[x][y].nil?
          yield x, y, blocks[x][y][:color]
        end
      end
    end
  end

end

shoes = Shoes.app :title => 'Tetris', :width => WIDTH, :height => HEIGHT do

  game = Tetris.new

  keypress do |k|
    case k
    when :left   then game.actions << :left
    when :right  then game.actions << :right
    when :down   then game.actions << :drop
    when :up     then game.actions << :rotate
    when :escape then quit
    end
  end

  def block(x, y, color)
    fill color
    rect(x*DX, y*DY, DX, DY)
  end

  last = now = Time.now
  animate = animate FPS do
    now = Time.now

    game.update(now - last)
    clear

    game.each_occupied_block do |x, y, color|
      block(x, y, color)
    end

    game.current.each_occupied_block do |x,y|
      block(x, y, game.current.type[:color])
    end
    last = now

    if game.lost?
      banner "Game Over", :align => 'center', :stroke => black
      animate.stop
    else
      subtitle "Score: #{format("%6.6d", game.vscore)}", :stroke => green, :align => 'right'
    end

  end

end
