#
# stringio.rb
#
# Copyright (c) 1999-2003 Minero Aoki <aamine@loveruby.net>
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU Lesser General Public License version 2 or later.
#
# Id: stringio.rb,v 1.10 2003/04/27 22:02:14 aamine Exp 
#

class StringInput#:nodoc:

  include Enumerable

  class << self

    def new( str )
      if block_given?
        begin
          f = super
          yield f
        ensure
          f.close if f
        end
      else
        super
      end
    end

    alias open new
  
  end

  def initialize( str )
    @src = str
    @pos = 0
    @closed = false
    @lineno = 0
  end

  attr_reader :lineno

  def string
    @src
  end

  def inspect
    "#<#{self.class}:#{@closed ? 'closed' : 'open'},src=#{@src[0,30].inspect}>"
  end

  def close
    stream_check!
    @pos = nil
    @closed = true
  end

  def closed?
    @closed
  end

  def pos
    stream_check!
    [@pos, @src.size].min
  end

  alias tell pos

  def seek( offset, whence = IO::SEEK_SET )
    stream_check!
    case whence
    when IO::SEEK_SET
      @pos = offset
    when IO::SEEK_CUR
      @pos += offset
    when IO::SEEK_END
      @pos = @src.size - offset
    else
      raise ArgumentError, "unknown seek flag: #{whence}"
    end
    @pos = 0 if @pos < 0
    @pos = [@pos, @src.size + 1].min
    offset
  end

  def rewind
    stream_check!
    @pos = 0
  end

  def eof?
    stream_check!
    @pos > @src.size
  end

  def each( &block )
    stream_check!
    begin
      @src.each(&block)
    ensure
      @pos = 0
    end
  end

  def gets
    stream_check!
    if idx = @src.index(?\n, @pos)
      idx += 1  # "\n".size
      line = @src[ @pos ... idx ]
      @pos = idx
      @pos += 1 if @pos == @src.size
    else
      line = @src[ @pos .. -1 ]
      @pos = @src.size + 1
    end
    @lineno += 1

    line
  end

  def getc
    stream_check!
    ch = @src[@pos]
    @pos += 1
    @pos += 1 if @pos == @src.size
    ch
  end

  def read( len = nil )
    stream_check!
    return read_all unless len
    str = @src[@pos, len]
    @pos += len
    @pos += 1 if @pos == @src.size
    str
  end

  alias sysread read

  def read_all
    stream_check!
    return nil if eof?
    rest = @src[@pos ... @src.size]
    @pos = @src.size + 1
    rest
  end

  def stream_check!
    @closed and raise IOError, 'closed stream'
  end

end


class StringOutput#:nodoc:

  class << self

    def new( str = '' )
      if block_given?
        begin
          f = super
          yield f
        ensure
          f.close if f
        end
      else
        super
      end
    end

    alias open new
  
  end

  def initialize( str = '' )
    @dest = str
    @closed = false
  end

  def close
    @closed = true
  end

  def closed?
    @closed
  end

  def string
    @dest
  end

  alias value string
  alias to_str string

  def size
    @dest.size
  end

  alias pos size

  def inspect
    "#<#{self.class}:#{@dest ? 'open' : 'closed'},#{id}>"
  end

  def print( *args )
    stream_check!
    raise ArgumentError, 'wrong # of argument (0 for >1)' if args.empty?
    args.each do |s|
      raise ArgumentError, 'nil not allowed' if s.nil?
      @dest << s.to_s
    end
    nil
  end

  def puts( *args )
    stream_check!
    args.each do |str|
      @dest << (s = str.to_s)
      @dest << "\n" unless s[-1] == ?\n
    end
    @dest << "\n" if args.empty?
    nil
  end

  def putc( ch )
    stream_check!
    @dest << ch.chr
    nil
  end

  def printf( *args )
    stream_check!
    @dest << sprintf(*args)
    nil
  end

  def write( str )
    stream_check!
    s = str.to_s
    @dest << s
    s.size
  end

  alias syswrite write

  def <<( str )
    stream_check!
    @dest << str.to_s
    self
  end

  private

  def stream_check!
    @closed and raise IOError, 'closed stream'
  end

end
