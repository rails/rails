#
# stringio.rb
#
#--
# Copyright (c) 1998-2003 Minero Aoki <aamine@loveruby.net>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# Note: Originally licensed under LGPL v2+. Using MIT license for Rails
# with permission of Minero Aoki.
#++

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
