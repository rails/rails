# frozen_string_literal: true

module ConnectionPoolBehavior
  def test_connection_pool_fetch
    Thread.report_on_exception, original_report_on_exception = false, Thread.report_on_exception

    threads = []
    results = []

    emulating_latency do
      cache = ActiveSupport::Cache.lookup_store(*store, { pool: { size: 2, timeout: 0.1 } }.merge(store_options))
      value = SecureRandom.alphanumeric
      base_key = "latency:#{SecureRandom.uuid}"

      # One of the three threads will fail in 1 second because our pool size
      # is only two.
      3.times do |i|
        threads << Thread.new do
          cache.fetch("#{base_key}:#{i}") { value }
        end
      end

      results = threads.map(&:value)
      assert_equal [value] * 3, results, "All threads should return the same value"
    ensure
      threads.each(&:kill)
    end
  ensure
    Thread.report_on_exception = original_report_on_exception
  end


  private
    def store_options; {}; end
end
