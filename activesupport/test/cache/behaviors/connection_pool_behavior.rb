# frozen_string_literal: true

module ConnectionPoolBehavior
  def test_connection_pool
    Thread.report_on_exception, original_report_on_exception = false, Thread.report_on_exception

    threads = []

    emulating_latency do
      cache = ActiveSupport::Cache.lookup_store(*store, { pool: { size: 2, timeout: 0.1 } }.merge(store_options))
      cache.read("foo")

      assert_nothing_raised do
        # One of the three threads will fail in 1 second because our pool size
        # is only two.
        3.times do
          threads << Thread.new do
            cache.read("latency")
          end
        end

        threads.each(&:join)
      end
    ensure
      threads.each(&:kill)
    end
  ensure
    Thread.report_on_exception = original_report_on_exception
  end

  def test_connection_pool_fetch
    Thread.report_on_exception, original_report_on_exception = false, Thread.report_on_exception

    threads = []
    results = []

    emulating_latency do
      cache = ActiveSupport::Cache.lookup_store(*store, { pool: { size: 2, timeout: 0.1 } }.merge(store_options))
      value = SecureRandom.alphanumeric
      base_key = "latency:#{SecureRandom.uuid}"

      assert_nothing_raised do
        # One of the three threads will fail in 1 second because our pool size
        # is only two.
        3.times do |i|
          threads << Thread.new do
            cache.fetch("#{base_key}:#{i}") { value }
          end
        end

        results = threads.map(&:value)
        assert_equal [value] * 3, results, "All threads should return the same value"
      end
    ensure
      threads.each(&:kill)
    end
  ensure
    Thread.report_on_exception = original_report_on_exception
  end

  def test_no_connection_pool
    threads = []

    emulating_latency do
      cache = ActiveSupport::Cache.lookup_store(*store, store_options.merge(pool: false))

      assert_nothing_raised do
        # Default connection pool size is 5, assuming 10 will make sure that
        # the connection pool isn't used at all.
        10.times do
          threads << Thread.new do
            cache.read("latency")
          end
        end

        threads.each(&:join)
      end
    ensure
      threads.each(&:kill)
    end
  end

  private
    def store_options; {}; end
end
