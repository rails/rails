#
# mailbox.rb
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

require 'tmail/port'
require 'socket'
require 'mutex_m'


unless [].respond_to?(:sort_by)
module Enumerable#:nodoc:
  def sort_by
    map {|i| [yield(i), i] }.sort {|a,b| a.first <=> b.first }.map {|i| i[1] }
  end
end
end


module TMail

  class MhMailbox

    PORT_CLASS = MhPort

    def initialize( dir )
      edir = File.expand_path(dir)
      raise ArgumentError, "not directory: #{dir}"\
                              unless FileTest.directory? edir
      @dirname = edir
      @last_file = nil
      @last_atime = nil
    end

    def directory
      @dirname
    end

    alias dirname directory

    attr_accessor :last_atime

    def inspect
      "#<#{self.class} #{@dirname}>"
    end

    def close
    end

    def new_port
      PORT_CLASS.new(next_file_name())
    end

    def each_port
      mail_files().each do |path|
        yield PORT_CLASS.new(path)
      end
      @last_atime = Time.now
    end

    alias each each_port

    def reverse_each_port
      mail_files().reverse_each do |path|
        yield PORT_CLASS.new(path)
      end
      @last_atime = Time.now
    end

    alias reverse_each reverse_each_port

    # old #each_mail returns Port
    #def each_mail
    #  each_port do |port|
    #    yield Mail.new(port)
    #  end
    #end

    def each_new_port( mtime = nil, &block )
      mtime ||= @last_atime
      return each_port(&block) unless mtime
      return unless File.mtime(@dirname) >= mtime

      mail_files().each do |path|
        yield PORT_CLASS.new(path) if File.mtime(path) > mtime
      end
      @last_atime = Time.now
    end

    private

    def mail_files
      Dir.entries(@dirname)\
              .select {|s| /\A\d+\z/ === s }\
              .map {|s| s.to_i }\
              .sort\
              .map {|i| "#{@dirname}/#{i}" }\
              .select {|path| FileTest.file? path }
    end

    def next_file_name
      unless n = @last_file
        n = 0
        Dir.entries(@dirname)\
                .select {|s| /\A\d+\z/ === s }\
                .map {|s| s.to_i }.sort\
        .each do |i|
          next unless FileTest.file? "#{@dirname}/#{i}"
          n = i
        end
      end
      begin
        n += 1
      end while FileTest.exist? "#{@dirname}/#{n}"
      @last_file = n

      "#{@dirname}/#{n}"
    end

  end   # MhMailbox

  MhLoader = MhMailbox


  class UNIXMbox
  
    def UNIXMbox.lock( fname )
      begin
        f = File.open(fname)
        f.flock File::LOCK_EX
        yield f
      ensure
        f.flock File::LOCK_UN
        f.close if f and not f.closed?
      end
    end

    class << self
      alias newobj new
    end

    def UNIXMbox.new( fname, tmpdir = nil, readonly = false )
      tmpdir = ENV['TEMP'] || ENV['TMP'] || '/tmp'
      newobj(fname, "#{tmpdir}/ruby_tmail_#{$$}_#{rand()}", readonly, false)
    end

    def UNIXMbox.static_new( fname, dir, readonly = false )
      newobj(fname, dir, readonly, true)
    end

    def initialize( fname, mhdir, readonly, static )
      @filename = fname
      @readonly = readonly
      @closed = false

      Dir.mkdir mhdir
      @real = MhMailbox.new(mhdir)
      @finalizer = UNIXMbox.mkfinal(@real, @filename, !@readonly, !static)
      ObjectSpace.define_finalizer self, @finalizer
    end

    def UNIXMbox.mkfinal( mh, mboxfile, writeback_p, cleanup_p )
      lambda {
          if writeback_p
            lock(mboxfile) {|f|
                mh.each_port do |port|
                  f.puts create_from_line(port)
                  port.ropen {|r|
                      f.puts r.read
                  }
                end
            }
          end
          if cleanup_p
            Dir.foreach(mh.dirname) do |fname|
              next if /\A\.\.?\z/ === fname
              File.unlink "#{mh.dirname}/#{fname}"
            end
            Dir.rmdir mh.dirname
          end
      }
    end

    # make _From line
    def UNIXMbox.create_from_line( port )
      sprintf 'From %s %s',
              fromaddr(), TextUtils.time2str(File.mtime(port.filename))
    end

    def UNIXMbox.fromaddr
      h = HeaderField.new_from_port(port, 'Return-Path') ||
          HeaderField.new_from_port(port, 'From') or return 'nobody'
      a = h.addrs[0] or return 'nobody'
      a.spec
    end
    private_class_method :fromaddr

    def close
      return if @closed

      ObjectSpace.undefine_finalizer self
      @finalizer.call
      @finalizer = nil
      @real = nil
      @closed = true
      @updated = nil
    end

    def each_port( &block )
      close_check
      update
      @real.each_port(&block)
    end

    alias each each_port

    def reverse_each_port( &block )
      close_check
      update
      @real.reverse_each_port(&block)
    end

    alias reverse_each reverse_each_port

    # old #each_mail returns Port
    #def each_mail( &block )
    #  each_port do |port|
    #    yield Mail.new(port)
    #  end
    #end

    def each_new_port( mtime = nil )
      close_check
      update
      @real.each_new_port(mtime) {|p| yield p }
    end

    def new_port
      close_check
      @real.new_port
    end

    private

    def close_check
      @closed and raise ArgumentError, 'accessing already closed mbox'
    end

    def update
      return if FileTest.zero?(@filename)
      return if @updated and File.mtime(@filename) < @updated
      w = nil
      port = nil
      time = nil
      UNIXMbox.lock(@filename) {|f|
          begin
            f.each do |line|
              if /\AFrom / === line
                w.close if w
                File.utime time, time, port.filename if time

                port = @real.new_port
                w = port.wopen
                time = fromline2time(line)
              else
                w.print line if w
              end
            end
          ensure
            if w and not w.closed?
              w.close
              File.utime time, time, port.filename if time
            end
          end
          f.truncate(0) unless @readonly
          @updated = Time.now
      }
    end

    def fromline2time( line )
      m = /\AFrom \S+ \w+ (\w+) (\d+) (\d+):(\d+):(\d+) (\d+)/.match(line) \
              or return nil
      Time.local(m[6].to_i, m[1], m[2].to_i, m[3].to_i, m[4].to_i, m[5].to_i)
    end

  end   # UNIXMbox

  MboxLoader = UNIXMbox


  class Maildir

    extend Mutex_m

    PORT_CLASS = MaildirPort

    @seq = 0
    def Maildir.unique_number
      synchronize {
          @seq += 1
          return @seq
      }
    end

    def initialize( dir = nil )
      @dirname = dir || ENV['MAILDIR']
      raise ArgumentError, "not directory: #{@dirname}"\
                              unless FileTest.directory? @dirname
      @new = "#{@dirname}/new"
      @tmp = "#{@dirname}/tmp"
      @cur = "#{@dirname}/cur"
    end

    def directory
      @dirname
    end

    def inspect
      "#<#{self.class} #{@dirname}>"
    end

    def close
    end

    def each_port
      mail_files(@cur).each do |path|
        yield PORT_CLASS.new(path)
      end
    end

    alias each each_port

    def reverse_each_port
      mail_files(@cur).reverse_each do |path|
        yield PORT_CLASS.new(path)
      end
    end

    alias reverse_each reverse_each_port

    def new_port
      fname = nil
      tmpfname = nil
      newfname = nil

      begin
        fname = "#{Time.now.to_i}.#{$$}_#{Maildir.unique_number}.#{Socket.gethostname}"
        
        tmpfname = "#{@tmp}/#{fname}"
        newfname = "#{@new}/#{fname}"
      end while FileTest.exist? tmpfname

      if block_given?
        File.open(tmpfname, 'w') {|f| yield f }
        File.rename tmpfname, newfname
        PORT_CLASS.new(newfname)
      else
        File.open(tmpfname, 'w') {|f| f.write "\n\n" }
        PORT_CLASS.new(tmpfname)
      end
    end

    def each_new_port
      mail_files(@new).each do |path|
        dest = @cur + '/' + File.basename(path)
        File.rename path, dest
        yield PORT_CLASS.new(dest)
      end

      check_tmp
    end

    TOO_OLD = 60 * 60 * 36   # 36 hour

    def check_tmp
      old = Time.now.to_i - TOO_OLD
      
      each_filename(@tmp) do |full, fname|
        if FileTest.file? full and
           File.stat(full).mtime.to_i < old
          File.unlink full
        end
      end
    end

    private

    def mail_files( dir )
      Dir.entries(dir)\
              .select {|s| s[0] != ?. }\
              .sort_by {|s| s.slice(/\A\d+/).to_i }\
              .map {|s| "#{dir}/#{s}" }\
              .select {|path| FileTest.file? path }
    end

    def each_filename( dir )
      Dir.foreach(dir) do |fname|
        path = "#{dir}/#{fname}"
        if fname[0] != ?. and FileTest.file? path
          yield path, fname
        end
      end
    end
    
  end   # Maildir

  MaildirLoader = Maildir

end   # module TMail
