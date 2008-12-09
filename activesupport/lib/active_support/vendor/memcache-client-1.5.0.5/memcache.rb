# All original code copyright 2005, 2006, 2007 Bob Cottrell, Eric Hodel,
# The Robot Co-op.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the names of the authors nor the names of their contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

$TESTING = defined?($TESTING) && $TESTING

require 'socket'
require 'thread'
require 'timeout'
require 'rubygems'
require 'zlib'

##
# A Ruby client library for memcached.
#
# This is intended to provide access to basic memcached functionality.  It
# does not attempt to be complete implementation of the entire API, but it is
# approaching a complete implementation.

class MemCache

  ##
  # The version of MemCache you are using.

  VERSION = '1.5.0.5'

  ##
  # Default options for the cache object.

  DEFAULT_OPTIONS = {
    :namespace   => nil,
    :readonly    => false,
    :multithread => false,
    :failover    => true
  }

  ##
  # Default memcached port.

  DEFAULT_PORT = 11211

  ##
  # Default memcached server weight.

  DEFAULT_WEIGHT = 1

  ##
  # The amount of time to wait for a response from a memcached server.  If a
  # response is not completed within this time, the connection to the server
  # will be closed and an error will be raised.

  attr_accessor :request_timeout

  ##
  # The namespace for this instance

  attr_reader :namespace

  ##
  # The multithread setting for this instance

  attr_reader :multithread

  ##
  # The servers this client talks to.  Play at your own peril.

  attr_reader :servers

  ##
  # Whether this client should failover reads and writes to another server

  attr_accessor :failover
  ##
  # Accepts a list of +servers+ and a list of +opts+.  +servers+ may be
  # omitted.  See +servers=+ for acceptable server list arguments.
  #
  # Valid options for +opts+ are:
  #
  #   [:namespace]   Prepends this value to all keys added or retrieved.
  #   [:readonly]    Raises an exception on cache writes when true.
  #   [:multithread] Wraps cache access in a Mutex for thread safety.
  #
  # Other options are ignored.

  def initialize(*args)
    servers = []
    opts = {}

    case args.length
    when 0 then # NOP
    when 1 then
      arg = args.shift
      case arg
      when Hash   then opts = arg
      when Array  then servers = arg
      when String then servers = [arg]
      else raise ArgumentError, 'first argument must be Array, Hash or String'
      end
    when 2 then
      servers, opts = args
    else
      raise ArgumentError, "wrong number of arguments (#{args.length} for 2)"
    end

    opts = DEFAULT_OPTIONS.merge opts
    @namespace   = opts[:namespace]
    @readonly    = opts[:readonly]
    @multithread = opts[:multithread]
    @failover      = opts[:failover]
    @mutex       = Mutex.new if @multithread
    @buckets     = []
    self.servers = servers
  end

  ##
  # Returns a string representation of the cache object.

  def inspect
    "<MemCache: %d servers, %d buckets, ns: %p, ro: %p>" %
      [@servers.length, @buckets.length, @namespace, @readonly]
  end

  ##
  # Returns whether there is at least one active server for the object.

  def active?
    not @servers.empty?
  end

  ##
  # Returns whether or not the cache object was created read only.

  def readonly?
    @readonly
  end

  ##
  # Set the servers that the requests will be distributed between.  Entries
  # can be either strings of the form "hostname:port" or
  # "hostname:port:weight" or MemCache::Server objects.

  def servers=(servers)
    # Create the server objects.
    @servers = Array(servers).collect do |server|
      case server
      when String
        host, port, weight = server.split ':', 3
        port ||= DEFAULT_PORT
        weight ||= DEFAULT_WEIGHT
        Server.new self, host, port, weight
      when Server
        if server.memcache.multithread != @multithread then
          raise ArgumentError, "can't mix threaded and non-threaded servers"
        end
        server
      else
        raise TypeError, "cannot convert #{server.class} into MemCache::Server"
      end
    end

    # Create an array of server buckets for weight selection of servers.
    @buckets = []
    @servers.each do |server|
      server.weight.times { @buckets.push(server) }
    end
  end

  ##
  # Decrements the value for +key+ by +amount+ and returns the new value.
  # +key+ must already exist.  If +key+ is not an integer, it is assumed to be
  # 0.  +key+ can not be decremented below 0.

  def decr(key, amount = 1)
    raise MemCacheError, "Update of readonly cache" if @readonly
    with_server(key) do |server, cache_key|
      cache_decr server, cache_key, amount
    end
  rescue TypeError => err
    handle_error nil, err
  end

  ##
  # Retrieves +key+ from memcache.  If +raw+ is false, the value will be
  # unmarshalled.

  def get(key, raw = false)
    with_server(key) do |server, cache_key|
      value = cache_get server, cache_key
      return nil if value.nil?
      value = Marshal.load value unless raw
      return value
    end
  rescue TypeError => err
    handle_error nil, err
  end

  ##
  # Retrieves multiple values from memcached in parallel, if possible.
  #
  # The memcached protocol supports the ability to retrieve multiple
  # keys in a single request.  Pass in an array of keys to this method
  # and it will:
  #
  # 1. map the key to the appropriate memcached server
  # 2. send a single request to each server that has one or more key values
  #
  # Returns a hash of values.
  #
  #   cache["a"] = 1
  #   cache["b"] = 2
  #   cache.get_multi "a", "b" # => { "a" => 1, "b" => 2 }

  def get_multi(*keys)
    raise MemCacheError, 'No active servers' unless active?

    keys.flatten!
    key_count = keys.length
    cache_keys = {}
    server_keys = Hash.new { |h,k| h[k] = [] }

    # map keys to servers
    keys.each do |key|
      server, cache_key = request_setup key
      cache_keys[cache_key] = key
      server_keys[server] << cache_key
    end

    results = {}

    server_keys.each do |server, keys_for_server|
      keys_for_server = keys_for_server.join ' '
      values = cache_get_multi server, keys_for_server
      values.each do |key, value|
        results[cache_keys[key]] = Marshal.load value
      end
    end

    return results
  rescue TypeError, IndexError => err
    handle_error nil, err
  end

  ##
  # Increments the value for +key+ by +amount+ and returns the new value.
  # +key+ must already exist.  If +key+ is not an integer, it is assumed to be
  # 0.

  def incr(key, amount = 1)
    raise MemCacheError, "Update of readonly cache" if @readonly
    with_server(key) do |server, cache_key|
      cache_incr server, cache_key, amount
    end
  rescue TypeError => err
    handle_error nil, err
  end

  ##
  # Add +key+ to the cache with value +value+ that expires in +expiry+
  # seconds.  If +raw+ is true, +value+ will not be Marshalled.
  #
  # Warning: Readers should not call this method in the event of a cache miss;
  # see MemCache#add.

  def set(key, value, expiry = 0, raw = false)
    raise MemCacheError, "Update of readonly cache" if @readonly
    with_server(key) do |server, cache_key|

      value = Marshal.dump value unless raw
      command = "set #{cache_key} 0 #{expiry} #{value.to_s.size}\r\n#{value}\r\n"

      with_socket_management(server) do |socket|
        socket.write command
        result = socket.gets
        raise_on_error_response! result

        if result.nil?
          server.close
          raise MemCacheError, "lost connection to #{server.host}:#{server.port}"
        end

        result
      end
    end
  end

  ##
  # Add +key+ to the cache with value +value+ that expires in +expiry+
  # seconds, but only if +key+ does not already exist in the cache.
  # If +raw+ is true, +value+ will not be Marshalled.
  #
  # Readers should call this method in the event of a cache miss, not
  # MemCache#set or MemCache#[]=.

  def add(key, value, expiry = 0, raw = false)
    raise MemCacheError, "Update of readonly cache" if @readonly
    with_server(key) do |server, cache_key|
      value = Marshal.dump value unless raw
      command = "add #{cache_key} 0 #{expiry} #{value.size}\r\n#{value}\r\n"

      with_socket_management(server) do |socket|
        socket.write command
        result = socket.gets
        raise_on_error_response! result
        result
      end
    end
  end

  ##
  # Removes +key+ from the cache in +expiry+ seconds.

  def delete(key, expiry = 0)
    raise MemCacheError, "Update of readonly cache" if @readonly
    with_server(key) do |server, cache_key|
      with_socket_management(server) do |socket|
        socket.write "delete #{cache_key} #{expiry}\r\n"
        result = socket.gets
        raise_on_error_response! result
        result
      end
    end
  end

  ##
  # Flush the cache from all memcache servers.

  def flush_all
    raise MemCacheError, 'No active servers' unless active?
    raise MemCacheError, "Update of readonly cache" if @readonly

    begin
      @mutex.lock if @multithread
      @servers.each do |server|
        with_socket_management(server) do |socket|
          socket.write "flush_all\r\n"
          result = socket.gets
          raise_on_error_response! result
          result
        end
      end
    rescue IndexError => err
      handle_error nil, err
    ensure
      @mutex.unlock if @multithread
    end
  end

  ##
  # Reset the connection to all memcache servers.  This should be called if
  # there is a problem with a cache lookup that might have left the connection
  # in a corrupted state.

  def reset
    @servers.each { |server| server.close }
  end

  ##
  # Returns statistics for each memcached server.  An explanation of the
  # statistics can be found in the memcached docs:
  #
  # http://code.sixapart.com/svn/memcached/trunk/server/doc/protocol.txt
  #
  # Example:
  #
  #   >> pp CACHE.stats
  #   {"localhost:11211"=>
  #     {"bytes"=>4718,
  #      "pid"=>20188,
  #      "connection_structures"=>4,
  #      "time"=>1162278121,
  #      "pointer_size"=>32,
  #      "limit_maxbytes"=>67108864,
  #      "cmd_get"=>14532,
  #      "version"=>"1.2.0",
  #      "bytes_written"=>432583,
  #      "cmd_set"=>32,
  #      "get_misses"=>0,
  #      "total_connections"=>19,
  #      "curr_connections"=>3,
  #      "curr_items"=>4,
  #      "uptime"=>1557,
  #      "get_hits"=>14532,
  #      "total_items"=>32,
  #      "rusage_system"=>0.313952,
  #      "rusage_user"=>0.119981,
  #      "bytes_read"=>190619}}
  #   => nil

  def stats
    raise MemCacheError, "No active servers" unless active?
    server_stats = {}

    @servers.each do |server|
      next unless server.alive?

      with_socket_management(server) do |socket|
        value = nil
        socket.write "stats\r\n"
        stats = {}
        while line = socket.gets do
          raise_on_error_response! line
          break if line == "END\r\n"
          if line =~ /\ASTAT ([\w]+) ([\w\.\:]+)/ then
            name, value = $1, $2
            stats[name] = case name
                          when 'version'
                            value
                          when 'rusage_user', 'rusage_system' then
                            seconds, microseconds = value.split(/:/, 2)
                            microseconds ||= 0
                            Float(seconds) + (Float(microseconds) / 1_000_000)
                          else
                            if value =~ /\A\d+\Z/ then
                              value.to_i
                            else
                              value
                            end
                          end
          end
        end
        server_stats["#{server.host}:#{server.port}"] = stats
      end
    end

    raise MemCacheError, "No active servers" if server_stats.empty?
    server_stats
  end

  ##
  # Shortcut to get a value from the cache.

  alias [] get

  ##
  # Shortcut to save a value in the cache.  This method does not set an
  # expiration on the entry.  Use set to specify an explicit expiry.

  def []=(key, value)
    set key, value
  end

  protected unless $TESTING

  ##
  # Create a key for the cache, incorporating the namespace qualifier if
  # requested.

  def make_cache_key(key)
    if namespace.nil? then
      key
    else
      "#{@namespace}:#{key}"
    end
  end

  ##
  # Pick a server to handle the request based on a hash of the key.

  def get_server_for_key(key, options = {})
    raise ArgumentError, "illegal character in key #{key.inspect}" if
      key =~ /\s/
    raise ArgumentError, "key too long #{key.inspect}" if key.length > 250
    raise MemCacheError, "No servers available" if @servers.empty?
    return @servers.first if @servers.length == 1

    hkey = hash_for key
    
    if @failover
      20.times do |try|
        server = @buckets[hkey % @buckets.compact.size]
        return server if server.alive?
        hkey += hash_for "#{try}#{key}"
      end
    else
      return @buckets[hkey % @buckets.compact.size]
    end
    
    raise MemCacheError, "No servers available"
  end

  ##
  # Returns an interoperable hash value for +key+.  (I think, docs are
  # sketchy for down servers).

  def hash_for(key)
    (Zlib.crc32(key) >> 16) & 0x7fff
  end

  ##
  # Performs a raw decr for +cache_key+ from +server+.  Returns nil if not
  # found.

  def cache_decr(server, cache_key, amount)
    with_socket_management(server) do |socket|
      socket.write "decr #{cache_key} #{amount}\r\n"
      text = socket.gets
      raise_on_error_response! text
      return nil if text == "NOT_FOUND\r\n"
      return text.to_i
    end
  end

  ##
  # Fetches the raw data for +cache_key+ from +server+.  Returns nil on cache
  # miss.

  def cache_get(server, cache_key)
    with_socket_management(server) do |socket|
      socket.write "get #{cache_key}\r\n"
      keyline = socket.gets # "VALUE <key> <flags> <bytes>\r\n"

      if keyline.nil? then
        server.close
        raise MemCacheError, "lost connection to #{server.host}:#{server.port}"
      end

      raise_on_error_response! keyline
      return nil if keyline == "END\r\n"

      unless keyline =~ /(\d+)\r/ then
        server.close
        raise MemCacheError, "unexpected response #{keyline.inspect}"
      end
      value = socket.read $1.to_i
      socket.read 2 # "\r\n"
      socket.gets   # "END\r\n"
      return value
    end
  end

  ##
  # Fetches +cache_keys+ from +server+ using a multi-get.

  def cache_get_multi(server, cache_keys)
    with_socket_management(server) do |socket|
      values = {}
      socket.write "get #{cache_keys}\r\n"

      while keyline = socket.gets do
        return values if keyline == "END\r\n"
        raise_on_error_response! keyline

        unless keyline =~ /\AVALUE (.+) (.+) (.+)/ then
          server.close
          raise MemCacheError, "unexpected response #{keyline.inspect}"
        end

        key, data_length = $1, $3
        values[$1] = socket.read data_length.to_i
        socket.read(2) # "\r\n"
      end

      server.close
      raise MemCacheError, "lost connection to #{server.host}:#{server.port}" # TODO: retry here too
    end
  end

  ##
  # Performs a raw incr for +cache_key+ from +server+.  Returns nil if not
  # found.

  def cache_incr(server, cache_key, amount)
    with_socket_management(server) do |socket|
      socket.write "incr #{cache_key} #{amount}\r\n"
      text = socket.gets
      raise_on_error_response! text
      return nil if text == "NOT_FOUND\r\n"
      return text.to_i
    end
  end

  ##
  # Gets or creates a socket connected to the given server, and yields it
  # to the block, wrapped in a mutex synchronization if @multithread is true.
  #
  # If a socket error (SocketError, SystemCallError, IOError) or protocol error
  # (MemCacheError) is raised by the block, closes the socket, attempts to
  # connect again, and retries the block (once).  If an error is again raised,
  # reraises it as MemCacheError.
  #
  # If unable to connect to the server (or if in the reconnect wait period),
  # raises MemCacheError.  Note that the socket connect code marks a server
  # dead for a timeout period, so retrying does not apply to connection attempt
  # failures (but does still apply to unexpectedly lost connections etc.).

  def with_socket_management(server, &block)
    @mutex.lock if @multithread
    retried = false
    
    begin
      socket = server.socket

      # Raise an IndexError to show this server is out of whack. If were inside
      # a with_server block, we'll catch it and attempt to restart the operation.
      
      raise IndexError, "No connection to server (#{server.status})" if socket.nil?
      
      block.call(socket)
      
    rescue SocketError => err
      server.mark_dead(err.message)
      handle_error(server, err)

    rescue MemCacheError, SocketError, SystemCallError, IOError => err
      handle_error(server, err) if retried || socket.nil?
      retried = true
      retry
    end
  ensure
    @mutex.unlock if @multithread
  end

  def with_server(key)
    retried = false
    begin
      server, cache_key = request_setup(key)
      yield server, cache_key
    rescue IndexError => e
      if !retried && @servers.size > 1
        puts "Connection to server #{server.inspect} DIED! Retrying operation..."
        retried = true
        retry
      end
      handle_error(nil, e)
    end
  end

  ##
  # Handles +error+ from +server+.

  def handle_error(server, error)
    raise error if error.is_a?(MemCacheError)
    server.close if server
    new_error = MemCacheError.new error.message
    new_error.set_backtrace error.backtrace
    raise new_error
  end

  ##
  # Performs setup for making a request with +key+ from memcached.  Returns
  # the server to fetch the key from and the complete key to use.

  def request_setup(key)
    raise MemCacheError, 'No active servers' unless active?
    cache_key = make_cache_key key
    server = get_server_for_key cache_key
    return server, cache_key
  end

  def raise_on_error_response!(response)
    if response =~ /\A(?:CLIENT_|SERVER_)?ERROR(.*)/
      raise MemCacheError, $1.strip
    end
  end

  ##
  # This class represents a memcached server instance.

  class Server

    ##
    # The amount of time to wait to establish a connection with a memcached
    # server.  If a connection cannot be established within this time limit,
    # the server will be marked as down.

    CONNECT_TIMEOUT = 0.25

    ##
    # The amount of time to wait for a response from a memcached server.
    # If a response isn't received within this time limit,
    # the server will be marked as down.

    SOCKET_TIMEOUT = 0.5

    ##
    # The amount of time to wait before attempting to re-establish a
    # connection with a server that is marked dead.

    RETRY_DELAY = 30.0

    ##
    # The host the memcached server is running on.

    attr_reader :host

    ##
    # The port the memcached server is listening on.

    attr_reader :port

    ##
    # The weight given to the server.

    attr_reader :weight

    ##
    # The time of next retry if the connection is dead.

    attr_reader :retry

    ##
    # A text status string describing the state of the server.

    attr_reader :status

    ##
    # Create a new MemCache::Server object for the memcached instance
    # listening on the given host and port, weighted by the given weight.

    def initialize(memcache, host, port = DEFAULT_PORT, weight = DEFAULT_WEIGHT)
      raise ArgumentError, "No host specified" if host.nil? or host.empty?
      raise ArgumentError, "No port specified" if port.nil? or port.to_i.zero?

      @memcache = memcache
      @host   = host
      @port   = port.to_i
      @weight = weight.to_i

      @multithread = @memcache.multithread
      @mutex = Mutex.new

      @sock   = nil
      @retry  = nil
      @status = 'NOT CONNECTED'
    end

    ##
    # Return a string representation of the server object.

    def inspect
      "<MemCache::Server: %s:%d [%d] (%s)>" % [@host, @port, @weight, @status]
    end

    ##
    # Check whether the server connection is alive.  This will cause the
    # socket to attempt to connect if it isn't already connected and or if
    # the server was previously marked as down and the retry time has
    # been exceeded.

    def alive?
      !!socket
    end

    ##
    # Try to connect to the memcached server targeted by this object.
    # Returns the connected socket object on success or nil on failure.

    def socket
      @mutex.lock if @multithread
      return @sock if @sock and not @sock.closed?

      @sock = nil

      # If the host was dead, don't retry for a while.
      return if @retry and @retry > Time.now

      # Attempt to connect if not already connected.
      begin

        @sock = TCPTimeoutSocket.new @host, @port

        if Socket.constants.include? 'TCP_NODELAY' then
          @sock.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
        end
        @retry  = nil
        @status = 'CONNECTED'
      rescue SocketError, SystemCallError, IOError, Timeout::Error => err
        mark_dead err.message
      end

      return @sock
    ensure
      @mutex.unlock if @multithread
    end

    ##
    # Close the connection to the memcached server targeted by this
    # object.  The server is not considered dead.

    def close
      @mutex.lock if @multithread
      @sock.close if @sock && !@sock.closed?
      @sock   = nil
      @retry  = nil
      @status = "NOT CONNECTED"
    ensure
      @mutex.unlock if @multithread
    end

    ##
    # Mark the server as dead and close its socket.

    def mark_dead(reason = "Unknown error")
      @sock.close if @sock && !@sock.closed?
      @sock   = nil
      @retry  = Time.now + RETRY_DELAY

      @status = sprintf "%s:%s DEAD: %s, will retry at %s", @host, @port, reason, @retry
    end

  end

  ##
  # Base MemCache exception class.

  class MemCacheError < RuntimeError; end

end

# TCPSocket facade class which implements timeouts.
class TCPTimeoutSocket
  def initialize(*args)
    Timeout::timeout(MemCache::Server::CONNECT_TIMEOUT, SocketError) do
      @sock = TCPSocket.new(*args)
      @len = MemCache::Server::SOCKET_TIMEOUT.to_f || 0.5
    end
  end
  
  def write(*args)
    Timeout::timeout(@len, SocketError) do
      @sock.write(*args)
    end
  end
  
  def gets(*args)
    Timeout::timeout(@len, SocketError) do
      @sock.gets(*args)
    end
  end
  
  def read(*args)
    Timeout::timeout(@len, SocketError) do
      @sock.read(*args)
    end
  end
  
  def _socket
    @sock
  end
  
  def method_missing(meth, *args)
    @sock.__send__(meth, *args)
  end
end