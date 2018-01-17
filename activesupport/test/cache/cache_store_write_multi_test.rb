# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"

class CacheStoreWriteMultiEntriesStoreProviderInterfaceTest < ActiveSupport::TestCase
  setup do
    @cache = ActiveSupport::Cache.lookup_store(:null_store)
  end

  test "fetch_multi uses write_multi_entries store provider interface" do
    assert_called_with(@cache, :write_multi_entries) do
      @cache.fetch_multi "a", "b", "c" do |key|
        key * 2
      end
    end
  end
end

class CacheStoreWriteMultiInstrumentationTest < ActiveSupport::TestCase
  setup do
    @cache = ActiveSupport::Cache.lookup_store(:memory_store)
  end

  test "instrumentation" do
    writes = { "a" => "aa", "b" => "bb" }

    events = with_instrumentation "write_multi" do
      @cache.write_multi(writes)
    end

    assert_equal %w[ cache_write_multi.active_support ], events.map(&:name)
    assert_nil events[0].payload[:super_operation]
    assert_equal({ "a" => "aa", "b" => "bb" }, events[0].payload[:key])
  end

  test "instrumentation with fetch_multi as super operation" do
    @cache.write("b", "bb")

    events = with_instrumentation "read_multi" do
      @cache.fetch_multi("a", "b") { |key| key * 2 }
    end

    assert_equal %w[ cache_read_multi.active_support ], events.map(&:name)
    assert_equal :fetch_multi, events[0].payload[:super_operation]
    assert_equal ["b"], events[0].payload[:hits]
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
