# frozen_string_literal: true

module ConnectionPoolBehavior
  def test_connection_pool
    Thread.report_on_exception, original_report_on_exception = false, Thread.report_on_exception

    emulating_latency do
      begin
        cache = ActiveSupport::Cache.lookup_store(store, { pool_size: 2, pool_timeout: 1 }.merge(store_options))
        cache.clear

        threads = []

        assert_raises Timeout::Error do
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
    end
  ensure
    Thread.report_on_exception = original_report_on_exception
  end

  def test_no_connection_pool
    emulating_latency do
      begin
        cache = ActiveSupport::Cache.lookup_store(store, store_options)
        cache.clear

        threads = []

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
  end

  private
    def store_options; {}; end
end
