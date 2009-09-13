$TESTING = defined?($TESTING) && $TESTING

require 'socket'
require 'thread'
require 'timeout'
require 'zlib'
require 'digest/sha1'

##
# A Ruby client library for memcached.
#

class MemCache

  ##
  # The version of MemCache you are using.

  VERSION = '1.6.4.99'

  ##
  # Default options for the cache object.

  DEFAULT_OPTIONS = {
    :namespace   => nil,
    :readonly    => false,
    :multithread => true,
    :failover    => true,
    :timeout     => 0.5,
    :logger      => nil,
  }

  ##
  # Default memcached port.

  DEFAULT_PORT = 11211

  ##
  # Default memcached server weight.

  DEFAULT_WEIGHT = 1

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
  # Socket timeout limit with this client, defaults to 0.5 sec.
  # Set to nil to disable timeouts.

  attr_reader :timeout

  ##
  # Should the client try to failover to another server if the
  # first server is down?  Defaults to true.

  attr_reader :failover

  ##
  # Log debug/info/warn/error to the given Logger, defaults to nil.

  attr_reader :logger

  ##
  # Accepts a list of +servers+ and a list of +opts+.  +servers+ may be
  # omitted.  See +servers=+ for acceptable server list arguments.
  #
  # Valid options for +opts+ are:
  #
  #   [:namespace]   Prepends this value to all keys added or retrieved.
  #   [:readonly]    Raises an exception on cache writes when true.
  #   [:multithread] Wraps cache access in a Mutex for thread safety.
  #   [:failover]    Should the client try to failover to another server if the
  #                  first server is down?  Defaults to true.
  #   [:timeout]     Time to use as the socket read timeout.  Defaults to 0.5 sec,
  #                  set to nil to disable timeouts (this is a major performance penalty in Ruby 1.8).
  #   [:logger]      Logger to use for info/debug output, defaults to nil
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
    @timeout     = opts[:timeout]
    @failover    = opts[:failover]
    @logger      = opts[:logger]
    @mutex       = Mutex.new if @multithread

    logger.info { "memcache-client #{VERSION} #{Array(servers).inspect}" } if logger

    Thread.current[:memcache_client] = self.object_id if !@multithread

    self.servers = servers
  end

  ##
  # Returns a string representation of the cache object.

  def inspect
    "<MemCache: %d servers, ns: %p, ro: %p>" %
      [@servers.length, @namespace, @readonly]
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
  #
  def servers=(servers)
    # Create the server objects.
    @servers = Array(servers).collect do |server|
      case server
      when String
        host, port, weight = server.split ':', 3
        port ||= DEFAULT_PORT
        weight ||= DEFAULT_WEIGHT
        Server.new self, host, port, weight
      else
        server
      end
    end

    logger.debug { "Servers now: #{@servers.inspect}" } if logger

    # There's no point in doing this if there's only one server
    @continuum = create_continuum_for(@servers) if @servers.size > 1

    @servers
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
      logger.debug { "GET #{key} from #{server.inspect}: #{value ? value.to_s.size : 'nil'}" } if logger
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
  #
  # Note that get_multi assumes the values are marshalled.

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
      keys_for_server_str = keys_for_server.join ' '
      begin
        values = cache_get_multi server, keys_for_server_str
        values.each do |key, value|
          results[cache_keys[key]] = Marshal.load value
        end
      rescue IndexError => e
        # Ignore this server and try the others
        logger.warn { "Unable to retrieve #{keys_for_server.size} elements from #{server.inspect}: #{e.message}"} if logger
      end
    end

    return results
  rescue TypeError => err
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

  ONE_MB = 1024 * 1024

  def set(key, value, expiry = 0, raw = false)
    raise MemCacheError, "Update of readonly cache" if @readonly
    with_server(key) do |server, cache_key|

      value = Marshal.dump value unless raw
      logger.debug { "SET #{key} to #{server.inspect}: #{value ? value.to_s.size : 'nil'}" } if logger

      data = value.to_s
      raise MemCacheError, "Value too large, memcached can only store 1MB of data per key" if data.size > ONE_MB

      command = "set #{cache_key} 0 #{expiry} #{data.size}\r\n#{data}\r\n"

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
      logger.debug { "ADD #{key} to #{server}: #{value ? value.to_s.size : 'nil'}" } if logger
      command = "add #{cache_key} 0 #{expiry} #{value.to_s.size}\r\n#{value}\r\n"

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
          if line =~ /\ASTAT ([\S]+) ([\w\.\:]+)/ then
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
  # Returns an interoperable hash value for +key+.  (I think, docs are
  # sketchy for down servers).

  def hash_for(key)
    Zlib.crc32(key)
  end

  ##
  # Pick a server to handle the request based on a hash of the key.

  def get_server_for_key(key, options = {})
    raise ArgumentError, "illegal character in key #{key.inspect}" if
      key =~ /\s/
    raise ArgumentError, "key too long #{key.inspect}" if key.length > 250
    raise MemCacheError, "No servers available" if @servers.empty?
    return @servers.first if @servers.length == 1

    hkey = hash_for(key)

    20.times do |try|
      entryidx = Continuum.binary_search(@continuum, hkey)
      server = @continuum[entryidx].server
      return server if server.alive?
      break unless failover
      hkey = hash_for "#{try}#{key}"
    end

    raise MemCacheError, "No servers available"
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
    check_multithread_status!

    @mutex.lock if @multithread
    retried = false

    begin
      socket = server.socket

      # Raise an IndexError to show this server is out of whack. If were inside
      # a with_server block, we'll catch it and attempt to restart the operation.

      raise IndexError, "No connection to server (#{server.status})" if socket.nil?

      block.call(socket)

    rescue SocketError => err
      logger.warn { "Socket failure: #{err.message}" } if logger
      server.mark_dead(err)
      handle_error(server, err)

    rescue MemCacheError, SystemCallError, IOError => err
      logger.warn { "Generic failure: #{err.class.name}: #{err.message}" } if logger
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
      logger.warn { "Server failed: #{e.class.name}: #{e.message}" } if logger
      if !retried && @servers.size > 1
        logger.info { "Connection to server #{server.inspect} DIED! Retrying operation..." } if logger
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

  def create_continuum_for(servers)
    total_weight = servers.inject(0) { |memo, srv| memo + srv.weight }
    continuum = []

    servers.each do |server|
      entry_count_for(server, servers.size, total_weight).times do |idx|
        hash = Digest::SHA1.hexdigest("#{server.host}:#{server.port}:#{idx}")
        value = Integer("0x#{hash[0..7]}")
        continuum << Continuum::Entry.new(value, server)
      end
    end

    continuum.sort { |a, b| a.value <=> b.value }
  end

  def entry_count_for(server, total_servers, total_weight)
    ((total_servers * Continuum::POINTS_PER_SERVER * server.weight) / Float(total_weight)).floor
  end

  def check_multithread_status!
    return if @multithread

    if Thread.current[:memcache_client] != self.object_id
      raise MemCacheError, <<-EOM
        You are accessing this memcache-client instance from multiple threads but have not enabled multithread support.
        Normally:  MemCache.new(['localhost:11211'], :multithread => true)
        In Rails:  config.cache_store = [:mem_cache_store, 'localhost:11211', { :multithread => true }]
      EOM
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

    attr_reader :logger

    ##
    # Create a new MemCache::Server object for the memcached instance
    # listening on the given host and port, weighted by the given weight.

    def initialize(memcache, host, port = DEFAULT_PORT, weight = DEFAULT_WEIGHT)
      raise ArgumentError, "No host specified" if host.nil? or host.empty?
      raise ArgumentError, "No port specified" if port.nil? or port.to_i.zero?

      @host   = host
      @port   = port.to_i
      @weight = weight.to_i

      @sock   = nil
      @retry  = nil
      @status = 'NOT CONNECTED'
      @timeout = memcache.timeout
      @logger = memcache.logger
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
      return @sock if @sock and not @sock.closed?

      @sock = nil

      # If the host was dead, don't retry for a while.
      return if @retry and @retry > Time.now

      # Attempt to connect if not already connected.
      begin
        @sock = @timeout ? TCPTimeoutSocket.new(@host, @port, @timeout) : TCPSocket.new(@host, @port)

        if Socket.constants.include? 'TCP_NODELAY' then
          @sock.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
        end
        @retry  = nil
        @status = 'CONNECTED'
      rescue SocketError, SystemCallError, IOError, Timeout::Error => err
        logger.warn { "Unable to open socket: #{err.class.name}, #{err.message}" } if logger
        mark_dead err
      end

      return @sock
    end

    ##
    # Close the connection to the memcached server targeted by this
    # object.  The server is not considered dead.

    def close
      @sock.close if @sock && !@sock.closed?
      @sock   = nil
      @retry  = nil
      @status = "NOT CONNECTED"
    end

    ##
    # Mark the server as dead and close its socket.

    def mark_dead(error)
      @sock.close if @sock && !@sock.closed?
      @sock   = nil
      @retry  = Time.now + RETRY_DELAY

      reason = "#{error.class.name}: #{error.message}"
      @status = sprintf "%s:%s DEAD (%s), will retry at %s", @host, @port, reason, @retry
      @logger.info { @status } if @logger
    end

  end

  ##
  # Base MemCache exception class.

  class MemCacheError < RuntimeError; end

end

# TCPSocket facade class which implements timeouts.
class TCPTimeoutSocket

  def initialize(host, port, timeout)
    Timeout::timeout(MemCache::Server::CONNECT_TIMEOUT, SocketError) do
      @sock = TCPSocket.new(host, port)
      @len = timeout
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

  def closed?
    @sock.closed?
  end

  def close
    @sock.close
  end
end

module Continuum
  POINTS_PER_SERVER = 160 # this is the default in libmemcached

  # Find the closest index in Continuum with value <= the given value
  def self.binary_search(ary, value, &block)
    upper = ary.size - 1
    lower = 0
    idx = 0

    while(lower <= upper) do
      idx = (lower + upper) / 2
      comp = ary[idx].value <=> value

      if comp == 0
        return idx
      elsif comp > 0
        upper = idx - 1
      else
        lower = idx + 1
      end
    end
    return upper
  end

  class Entry
    attr_reader :value
    attr_reader :server

    def initialize(val, srv)
      @value = val
      @server = srv
    end

    def inspect
      "<#{value}, #{server.host}:#{server.port}>"
    end
  end
end
