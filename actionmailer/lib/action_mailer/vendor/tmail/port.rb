#
# port.rb
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

require 'tmail/stringio'


module TMail

  class Port
    def reproducible?
      false
    end
  end


  ###
  ### FilePort
  ###

  class FilePort < Port

    def initialize( fname )
      @filename = File.expand_path(fname)
      super()
    end

    attr_reader :filename

    alias ident filename

    def ==( other )
      other.respond_to?(:filename) and @filename == other.filename
    end

    alias eql? ==

    def hash
      @filename.hash
    end

    def inspect
      "#<#{self.class}:#{@filename}>"
    end

    def reproducible?
      true
    end

    def size
      File.size @filename
    end


    def ropen( &block )
      File.open(@filename, &block)
    end

    def wopen( &block )
      File.open(@filename, 'w', &block)
    end

    def aopen( &block )
      File.open(@filename, 'a', &block)
    end


    def read_all
      ropen {|f|
          return f.read
      }
    end


    def remove
      File.unlink @filename
    end

    def move_to( port )
      begin
        File.link @filename, port.filename
      rescue Errno::EXDEV
        copy_to port
      end
      File.unlink @filename
    end

    alias mv move_to

    def copy_to( port )
      if FilePort === port
        copy_file @filename, port.filename
      else
        File.open(@filename) {|r|
        port.wopen {|w|
            while s = r.sysread(4096)
              w.write << s
            end
        } }
      end
    end

    alias cp copy_to

    private

    # from fileutils.rb
    def copy_file( src, dest )
      st = r = w = nil

      File.open(src,  'rb') {|r|
      File.open(dest, 'wb') {|w|
          st = r.stat
          begin
            while true
              w.write r.sysread(st.blksize)
            end
          rescue EOFError
          end
      } }
    end

  end


  module MailFlags

    def seen=( b )
      set_status 'S', b
    end

    def seen?
      get_status 'S'
    end

    def replied=( b )
      set_status 'R', b
    end

    def replied?
      get_status 'R'
    end

    def flagged=( b )
      set_status 'F', b
    end

    def flagged?
      get_status 'F'
    end

    private

    def procinfostr( str, tag, true_p )
      a = str.upcase.split(//)
      a.push true_p ? tag : nil
      a.delete tag unless true_p
      a.compact.sort.join('').squeeze
    end
  
  end


  class MhPort < FilePort

    include MailFlags

    private
    
    def set_status( tag, flag )
      begin
        tmpfile = @filename + '.tmailtmp.' + $$.to_s
        File.open(tmpfile, 'w') {|f|
          write_status f, tag, flag
        }
        File.unlink @filename
        File.link tmpfile, @filename
      ensure
        File.unlink tmpfile
      end
    end

    def write_status( f, tag, flag )
      stat = ''
      File.open(@filename) {|r|
        while line = r.gets
          if line.strip.empty?
            break
          elsif m = /\AX-TMail-Status:/i.match(line)
            stat = m.post_match.strip
          else
            f.print line
          end
        end

        s = procinfostr(stat, tag, flag)
        f.puts 'X-TMail-Status: ' + s unless s.empty?
        f.puts

        while s = r.read(2048)
          f.write s
        end
      }
    end

    def get_status( tag )
      File.foreach(@filename) {|line|
        return false if line.strip.empty?
        if m = /\AX-TMail-Status:/i.match(line)
          return m.post_match.strip.include?(tag[0])
        end
      }
      false
    end
  
  end


  class MaildirPort < FilePort

    def move_to_new
      new = replace_dir(@filename, 'new')
      File.rename @filename, new
      @filename = new
    end

    def move_to_cur
      new = replace_dir(@filename, 'cur')
      File.rename @filename, new
      @filename = new
    end

    def replace_dir( path, dir )
      "#{File.dirname File.dirname(path)}/#{dir}/#{File.basename path}"
    end
    private :replace_dir


    include MailFlags

    private

    MAIL_FILE = /\A(\d+\.[\d_]+\.[^:]+)(?:\:(\d),(\w+)?)?\z/

    def set_status( tag, flag )
      if m = MAIL_FILE.match(File.basename(@filename))
        s, uniq, type, info, = m.to_a
        return if type and type != '2'  # do not change anything
        newname = File.dirname(@filename) + '/' +
                  uniq + ':2,' + procinfostr(info.to_s, tag, flag)
      else
        newname = @filename + ':2,' + tag
      end

      File.link @filename, newname
      File.unlink @filename
      @filename = newname
    end

    def get_status( tag )
      m = MAIL_FILE.match(File.basename(@filename)) or return false
      m[2] == '2' and m[3].to_s.include?(tag[0])
    end
  
  end


  ###
  ###  StringPort
  ###

  class StringPort < Port

    def initialize( str = '' )
      @buffer = str
      super()
    end

    def string
      @buffer
    end

    def to_s
      @buffer.dup
    end

    alias read_all to_s

    def size
      @buffer.size
    end

    def ==( other )
      StringPort === other and @buffer.equal? other.string
    end

    alias eql? ==

    def hash
      @buffer.object_id.hash
    end

    def inspect
      "#<#{self.class}:id=#{sprintf '0x%x', @buffer.object_id}>"
    end

    def reproducible?
      true
    end

    def ropen( &block )
      @buffer or raise Errno::ENOENT, "#{inspect} is already removed"
      StringInput.open(@buffer, &block)
    end

    def wopen( &block )
      @buffer = ''
      StringOutput.new(@buffer, &block)
    end

    def aopen( &block )
      @buffer ||= ''
      StringOutput.new(@buffer, &block)
    end

    def remove
      @buffer = nil
    end

    alias rm remove

    def copy_to( port )
      port.wopen {|f|
          f.write @buffer
      }
    end

    alias cp copy_to

    def move_to( port )
      if StringPort === port
        str = @buffer
        port.instance_eval { @buffer = str }
      else
        copy_to port
      end
      remove
    end

  end

end   # module TMail
