require 'thread'
require 'switchtower/ssh'

Thread.abort_on_exception = true

module SwitchTower

  # Black magic. It uses threads and Net::SSH to set up a connection to a
  # gateway server, through which connections to other servers may be
  # tunnelled.
  #
  # It is used internally by Actor, but may be useful on its own, as well.
  #
  # Usage:
  #
  #   config = SwitchTower::Configuration.new
  #   gateway = SwitchTower::Gateway.new('gateway.example.com', config)
  #
  #   sess1 = gateway.connect_to('hidden.example.com')
  #   sess2 = gateway.connect_to('other.example.com')
  class Gateway
    # The thread inside which the gateway connection itself is running.
    attr_reader :thread

    # The Net::SSH session representing the gateway connection.
    attr_reader :session

    def initialize(server, config) #:nodoc:
      @config = config
      @pending_forward_requests = {}
      @mutex = Mutex.new
      @next_port = 31310
      @terminate_thread = false

      waiter = ConditionVariable.new

      @thread = Thread.new do
        @config.logger.trace "starting connection to gateway #{server}"
        SSH.connect(server, @config) do |@session|
          @config.logger.trace "gateway connection established"
          @mutex.synchronize { waiter.signal }
          connection = @session.registry[:connection][:driver]
          loop do
            break if @terminate_thread
            sleep 0.1 unless connection.reader_ready?
            connection.process true
            Thread.new { process_next_pending_connection_request }
          end
        end
      end

      @mutex.synchronize { waiter.wait(@mutex) }
    end

    # Shuts down all forwarded connections and terminates the gateway.
    def shutdown!
      # cancel all active forward channels
      @session.forward.active_locals.each do |lport, host, port|
        @session.forward.cancel_local(lport)
      end

      # terminate the gateway thread
      @terminate_thread = true

      # wait for the gateway thread to stop
      @thread.join
    end

    # Connects to the given server by opening a forwarded port from the local
    # host to the server, via the gateway, and then opens and returns a new
    # Net::SSH connection via that port.
    def connect_to(server)
      @mutex.synchronize do
        @pending_forward_requests[server] = ConditionVariable.new
        @pending_forward_requests[server].wait(@mutex)
        @pending_forward_requests.delete(server)
      end
    end

    private

      def process_next_pending_connection_request
        @mutex.synchronize do
          key = @pending_forward_requests.keys.detect { |k| ConditionVariable === @pending_forward_requests[k] } or return
          var = @pending_forward_requests[key]

          @config.logger.trace "establishing connection to #{key} via gateway"

          port = @next_port
          @next_port += 1

          begin
            @session.forward.local(port, key, 22)
            @pending_forward_requests[key] = SSH.connect('127.0.0.1', @config,
              port)
            @config.logger.trace "connection to #{key} via gateway established"
          rescue Object
            @pending_forward_requests[key] = nil
            raise
          ensure
            var.signal
          end
        end
      end
  end
end
