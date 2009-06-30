module ActiveSupport::Testing
  class ProxyTestResult
    def initialize
      @calls = []
    end

    def __replay__(result)
      @calls.each do |name, args|
        result.send(name, *args)
      end
    end

    def method_missing(name, *args)
      @calls << [name, args]
    end
  end

  module Isolation
    def run(result)
      yield(Test::Unit::TestCase::STARTED, name)

      read, write = IO.pipe

      pid = fork do
        # child
        read.close
        proxy = ProxyTestResult.new
        super(proxy) { }
        write.puts [Marshal.dump(proxy)].pack("m")
        exit!
      end

      write.close
      Marshal.load(read.read.unpack("m")[0]).__replay__(result)
      Process.wait2(pid)
      yield(Test::Unit::TestCase::FINISHED, name)
    end
  end
end