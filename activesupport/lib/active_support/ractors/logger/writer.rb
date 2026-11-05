# frozen_string_literal: true

module ActiveSupport
  module Ractors # :nodoc:
    class Logger # :nodoc:
      class Writer # :nodoc:
        def self.spawn(...)
          new.spawn(...)
        end

        def initialize
          unless defined?(::Ractor::Port)
            raise NotImplementedError, "ActiveSupport::Ractors::Logger requires Ractor::Port support"
          end

          @port = ::Ractor::Port.new
        end

        def spawn(logdev = nil, shift_age = 0, shift_size = 1048576, binmode: false, shift_period_suffix: "%Y%m%d")
          device = build_logdev(logdev, shift_age, shift_size, binmode, shift_period_suffix)
          start_consumer(@port, device)
          ::Ractor.make_shareable(self)
        end

        def async(message)
          @port << [:write, message]
        rescue ::Ractor::ClosedError
          # Consumer is gone; drop the line rather than raising in the caller.
          nil
        end

        def call(operation, *args)
          reply = reply_port
          @port << [:call, reply, operation, args]
          status, value = reply.receive
          raise RuntimeError, value if status == :error
          value
        rescue ::Ractor::ClosedError
          # Consumer is gone; degrade to a no-op rather than raising in the caller.
          nil
        end

        def flush
          call(:flush)
        end

        def reopen(log, options)
          call(:reopen, log, options)
        end

        def shutdown
          call(:shutdown) unless @port.closed?
        ensure
          @port.close
        end

        private
          # Reuse one reply port per calling thread instead of allocating one per call. A thread blocks on its own reply,
          # so its calls are serial and the port is safe to reuse.
          def reply_port
            ::Thread.current.thread_variable_get(:active_support_shareable_logger_reply_port) ||
              ::Thread.current.thread_variable_set(:active_support_shareable_logger_reply_port, ::Ractor::Port.new)
          end

          def build_logdev(logdev, shift_age, shift_size, binmode, shift_period_suffix)
            return NullDevice.new if logdev.nil?

            ::Logger::LogDevice.new(logdev,
              shift_age: shift_age,
              shift_size: shift_size,
              shift_period_suffix: shift_period_suffix,
              binmode: binmode)
          end

          # The consumer must survive a failing log device the same way the stock Logger does: a write error is swallowed
          # and reported to stderr, and the logger keeps working.
          def start_consumer(port, logdev)
            Thread.new do
              closed = false
              until closed
                begin
                  message = port.receive
                rescue ::Ractor::ClosedError
                  # Port closed; nothing left to consume.
                  break
                end
                case message[0]
                when :write
                  begin
                    logdev.write(message[1])
                  rescue StandardError => error
                    warn_failure(error)
                  end
                when :call
                  _, reply, operation, args = message
                  begin
                    case operation
                    when :flush
                      flush_device(logdev)
                    when :reopen
                      logdev.reopen(args[0], **args[1])
                    when :shutdown
                      flush_device(logdev)
                      logdev.close
                      closed = true
                    end
                  rescue StandardError => error
                    warn_failure(error)
                  ensure
                    reply << [:ok, operation == :shutdown ? true : :ok]
                  end
                end
              end
            ensure
              # On an unexpected exit close the port too, so producers get a ClosedError instead of blocking forever on a
              # dead consumer.
              unless closed
                logdev.close
                port.close
              end
            end
          end

          def warn_failure(error)
            warn "[ActiveSupport::Ractors::Logger::Writer] #{error.class}: #{error.message}"
          end

          def flush_device(logdev)
            dev = logdev.respond_to?(:dev) ? logdev.dev : logdev
            dev.flush if dev.respond_to?(:flush)
          end

          class NullDevice # :nodoc:
            def write(_message); end
            def reopen(*); end
            def close; end
          end
      end
    end
  end
end
