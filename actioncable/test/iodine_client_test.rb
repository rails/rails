# frozen_string_literal: true

require "client_test"

# test with iodine if platform allows
begin
  require "iodine"
rescue LoadError
else
  Iodine.verbosity = 2 # only print errors and fatal errors
  Iodine.workers = 1 # single process (no cluster)
  Iodine.threads = 1 # single threaded mode

  class IodineClientTest < ActionCable::TestCase
    include ClientTest

    def with_cable_server(rack_app = ActionCable.server, port = 3099)
      ::Iodine.listen2http(app: rack_app, port: port.to_s, address: "127.0.0.1")
      t = Thread.new { ::Iodine.start }
      begin
        yield(port)
      ensure
        ::Iodine.stop
        t.join
      end
    end
  end

end
