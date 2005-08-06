module SwitchTower

  # This class encapsulates a single command to be executed on a set of remote
  # machines, in parallel.
  class Command
    attr_reader :servers, :command, :options, :actor

    def initialize(servers, command, callback, options, actor) #:nodoc:
      @servers = servers
      @command = command.gsub(/\r?\n/, "\\\n")
      @callback = callback
      @options = options
      @actor = actor
      @channels = open_channels
    end

    def logger #:nodoc:
      actor.logger
    end

    # Processes the command in parallel on all specified hosts. If the command
    # fails (non-zero return code) on any of the hosts, this will raise a
    # RuntimeError.
    def process!
      logger.debug "processing command"

      loop do
        active = 0
        @channels.each do |ch|
          next if ch[:closed]
          active += 1
          ch.connection.process(true)
        end

        break if active == 0
      end

      logger.trace "command finished"

      if failed = @channels.detect { |ch| ch[:status] != 0 }
        raise "command #{@command.inspect} failed on #{failed[:host]}"
      end

      self
    end

    private

      def open_channels
        @servers.map do |server|
          @actor.sessions[server].open_channel do |channel|
            channel[:host] = server
            channel.request_pty :want_reply => true

            channel.on_success do |ch|
              logger.trace "executing command", ch[:host]
              ch.exec command
              ch.send_data options[:data] if options[:data]
            end

            channel.on_failure do |ch|
              logger.important "could not open channel", ch[:host]
              ch.close
            end

            channel.on_data do |ch, data|
              @callback[ch, :out, data] if @callback
            end

            channel.on_extended_data do |ch, type, data|
              @callback[ch, :err, data] if @callback
            end

            channel.on_request do |ch, request, reply, data|
              ch[:status] = data.read_long if request == "exit-status"
            end

            channel.on_close do |ch|
              ch[:closed] = true
            end
          end
        end
      end
  end
end
