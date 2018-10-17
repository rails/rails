# frozen_string_literal: true

require "client_test"

class PumaClientTest < ActionCable::TestCase
  include ClientTest

  def with_cable_server(rack_app = ActionCable.server, port = 3099)
    server = ::Puma::Server.new(rack_app, ::Puma::Events.strings)
    server.add_tcp_listener "127.0.0.1", port
    server.min_threads = 1
    server.max_threads = 4

    thread = server.run

    begin
      yield(port)

    ensure
      server.stop

      begin
        thread.join

      rescue IOError
        # Work around https://bugs.ruby-lang.org/issues/13405
        #
        # Puma's sometimes raising while shutting down, when it closes
        # its internal pipe. We can safely ignore that, but we do need
        # to do the step skipped by the exception:
        server.binder.close

      rescue RuntimeError => ex
        # Work around https://bugs.ruby-lang.org/issues/13239
        raise unless ex.message =~ /can't modify frozen IOError/

        # Handle this as if it were the IOError: do the same as above.
        server.binder.close
      end
    end
  end
end
