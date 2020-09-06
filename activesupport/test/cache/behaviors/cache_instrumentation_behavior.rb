# frozen_string_literal: true

module CacheInstrumentationBehavior
  def test_fetch_multi_uses_write_multi_entries_store_provider_interface
    assert_called(@cache, :write_multi_entries) do
      @cache.fetch_multi 'a', 'b', 'c' do |key|
        key * 2
      end
    end
  end

  def test_write_multi_instrumentation
    writes = { 'a' => 'aa', 'b' => 'bb' }

    events = with_instrumentation 'write_multi' do
      @cache.write_multi(writes)
    end

    assert_equal %w[ cache_write_multi.active_support ], events.map(&:name)
    assert_nil events[0].payload[:super_operation]
    assert_equal({ 'a' => 'aa', 'b' => 'bb' }, events[0].payload[:key])
  end

  def test_instrumentation_with_fetch_multi_as_super_operation
    @cache.write('b', 'bb')

    events = with_instrumentation 'read_multi' do
      @cache.fetch_multi('a', 'b') { |key| key * 2 }
    end

    assert_equal %w[ cache_read_multi.active_support ], events.map(&:name)
    assert_equal :fetch_multi, events[0].payload[:super_operation]
    assert_equal ['a', 'b'], events[0].payload[:key]
    assert_equal ['b'], events[0].payload[:hits]
  end

  def test_instrumentation_empty_fetch_multi
    events = with_instrumentation 'read_multi' do
      @cache.fetch_multi() { |key| key * 2 }
    end

    assert_equal %w[ cache_read_multi.active_support ], events.map(&:name)
    assert_equal :fetch_multi, events[0].payload[:super_operation]
    assert_equal [], events[0].payload[:key]
    assert_equal [], events[0].payload[:hits]
  end

  def test_read_multi_instrumentation
    @cache.write('b', 'bb')

    events = with_instrumentation 'read_multi' do
      @cache.read_multi('a', 'b')
    end

    assert_equal %w[ cache_read_multi.active_support ], events.map(&:name)
    assert_equal ['a', 'b'], events[0].payload[:key]
    assert_equal ['b'], events[0].payload[:hits]
  end

  def test_empty_read_multi_instrumentation
    events = with_instrumentation 'read_multi' do
      @cache.read_multi()
    end

    assert_equal %w[ cache_read_multi.active_support ], events.map(&:name)
    assert_equal [], events[0].payload[:key]
    assert_equal [], events[0].payload[:hits]
  end

  private
    def with_instrumentation(method)
      event_name = "cache_#{method}.active_support"

      [].tap do |events|
        ActiveSupport::Notifications.subscribe event_name do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end
        yield
      end
    ensure
      ActiveSupport::Notifications.unsubscribe event_name
    end
end
