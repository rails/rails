# frozen_string_literal: true

require "helper"
require "active_support/core_ext/time"
require "models/person"

class DebouncingTest < ActiveJob::TestCase
  class MemoryClaimStore
    def initialize
      @claims = {}
    end

    def claim(key, expires_in:)
      prune
      if @claims.key?(key)
        false
      else
        @claims[key] = Time.now + expires_in
        true
      end
    end

    def claimed?(key)
      prune
      @claims.key?(key)
    end

    def reset
      @claims.clear
    end

    private
      def prune
        @claims.delete_if { |_key, expires_at| expires_at <= Time.now }
      end
  end

  module UnavailableStore
    def self.claim(key, expires_in:)
      nil
    end
  end

  STORE = MemoryClaimStore.new

  class DebouncedJob < ActiveJob::Base
    debounce within: 30.seconds, by: ->(key) { key }, store: STORE

    def perform(key)
    end
  end

  class OtherDebouncedJob < ActiveJob::Base
    debounce within: 30.seconds, by: ->(key) { key }, store: STORE

    def perform(key)
    end
  end

  class ArgumentKeyedJob < ActiveJob::Base
    debounce within: 30.seconds, by: :first_argument, store: STORE

    def perform(key)
    end

    private
      def first_argument
        arguments.first
      end
  end

  class RecordKeyedJob < ActiveJob::Base
    debounce within: 30.seconds, by: ->(record) { record }, store: STORE

    def perform(record)
    end
  end

  class ScopedJob < ActiveJob::Base
    debounce within: 30.seconds, scope: "shared_scope", store: STORE

    def perform(key)
    end
  end

  class UnkeyedJob < ActiveJob::Base
    debounce within: 30.seconds, store: STORE

    def perform(key)
    end
  end

  class TrailingDebounceJob < ActiveJob::Base
    debounce within: 30.seconds, by: ->(key) { key }, leading: false, store: STORE

    def perform(key)
    end
  end

  class LeadingDebounceJob < ActiveJob::Base
    debounce within: 30.seconds, by: ->(key) { key }, trailing: false, store: STORE

    def perform(key)
    end
  end

  class FailingOpenJob < ActiveJob::Base
    debounce within: 30.seconds, by: ->(key) { key }, store: UnavailableStore

    def perform(key)
    end
  end

  setup do
    STORE.reset
  end

  def queue_adapter_for_test
    ActiveJob::QueueAdapters::TestAdapter.new
  end

  test "the leading call enqueues immediately and later calls coalesce into one trailing job" do
    freeze_time do
      leading = assert_enqueued_with(job: DebouncedJob, args: [ "badge" ]) { DebouncedJob.perform_later("badge") }
      assert_nil leading.scheduled_at

      assert_enqueued_with job: DebouncedJob, args: [ "badge" ], at: 30.seconds.from_now do
        DebouncedJob.perform_later("badge")
      end

      assert_no_enqueued_jobs only: DebouncedJob do
        assert_equal false, DebouncedJob.perform_later("badge")
      end
    end
  end

  test "a trailing job waits a full window from the trailing call, not the leading one" do
    freeze_time
    DebouncedJob.perform_later("badge")

    travel 10.seconds
    assert_enqueued_with job: DebouncedJob, args: [ "badge" ], at: 30.seconds.from_now do
      DebouncedJob.perform_later("badge")
    end
  end

  test "leads again once the window expires" do
    freeze_time
    2.times { DebouncedJob.perform_later("badge") }

    travel 31.seconds
    leading = assert_enqueued_with(job: DebouncedJob, args: [ "badge" ]) { DebouncedJob.perform_later("badge") }
    assert_nil leading.scheduled_at
  end

  test "debounces are keyed independently per identity and per job class" do
    DebouncedJob.perform_later("badge")

    other_identity = assert_enqueued_with(job: DebouncedJob, args: [ "tray" ]) { DebouncedJob.perform_later("tray") }
    assert_nil other_identity.scheduled_at

    other_class = assert_enqueued_with(job: OtherDebouncedJob, args: [ "badge" ]) { OtherDebouncedJob.perform_later("badge") }
    assert_nil other_class.scheduled_at
  end

  test "a symbol by: resolves against the job" do
    ArgumentKeyedJob.perform_later("badge")

    assert STORE.claimed?("debounce:debouncing_test/argument_keyed_job:badge:leading")
  end

  test "a by: result with a cache_key is keyed by it" do
    person = Person.new(7)
    def person.cache_key
      "people/7"
    end

    RecordKeyedJob.perform_later(person)

    assert STORE.claimed?("debounce:debouncing_test/record_keyed_job:people/7:leading")
  end

  test "scope: overrides the class-name key scope" do
    ScopedJob.perform_later("badge")

    assert STORE.claimed?("debounce:shared_scope:leading")
  end

  test "without by: the whole class shares one debounce" do
    freeze_time do
      leading = assert_enqueued_with(job: UnkeyedJob, args: [ "one" ]) { UnkeyedJob.perform_later("one") }
      assert_nil leading.scheduled_at

      assert_enqueued_with job: UnkeyedJob, args: [ "two" ], at: 30.seconds.from_now do
        UnkeyedJob.perform_later("two")
      end

      assert STORE.claimed?("debounce:debouncing_test/unkeyed_job:leading")
    end
  end

  test "an explicit set(wait:) bypasses debouncing" do
    freeze_time do
      3.times { DebouncedJob.perform_later("badge") }

      assert_enqueued_with job: DebouncedJob, args: [ "badge" ], at: 5.minutes.from_now do
        DebouncedJob.set(wait: 5.minutes).perform_later("badge")
      end
    end
  end

  test "retries are never absorbed" do
    3.times { DebouncedJob.perform_later("badge") }

    retried = DebouncedJob.new("badge")
    retried.executions = 1
    assert_enqueued_with(job: DebouncedJob, args: [ "badge" ]) { retried.enqueue }
    assert_nil retried.scheduled_at
  end

  test "fails open to immediate enqueues when the store is unavailable" do
    2.times do
      job = assert_enqueued_with(job: FailingOpenJob, args: [ "badge" ]) { FailingOpenJob.perform_later("badge") }
      assert_nil job.scheduled_at
    end
  end

  test "leading: false schedules one sweep a full window out and suppresses the rest" do
    freeze_time do
      assert_enqueued_with job: TrailingDebounceJob, args: [ "badge" ], at: 30.seconds.from_now do
        TrailingDebounceJob.perform_later("badge")
      end

      assert_no_enqueued_jobs only: TrailingDebounceJob do
        assert_equal false, TrailingDebounceJob.perform_later("badge")
        assert_equal false, TrailingDebounceJob.perform_later("badge")
      end
    end
  end

  test "trailing: false suppresses calls after the leading enqueue" do
    leading = assert_enqueued_with(job: LeadingDebounceJob, args: [ "badge" ]) { LeadingDebounceJob.perform_later("badge") }
    assert_nil leading.scheduled_at

    assert_no_enqueued_jobs only: LeadingDebounceJob do
      assert_equal false, LeadingDebounceJob.perform_later("badge")
    end
  end

  test "the default CacheStore wins a claim once per key and passes an outage nil through" do
    previous_rails = Object.send(:remove_const, :Rails) if defined?(::Rails)
    Object.const_set(:Rails, Struct.new(:cache).new(ActiveSupport::Cache::MemoryStore.new))

    assert_equal true, ActiveJob::Debouncing::CacheStore.claim("debounce:cache_store_test:leading", expires_in: 30.seconds)
    assert_equal false, ActiveJob::Debouncing::CacheStore.claim("debounce:cache_store_test:leading", expires_in: 30.seconds)

    Rails.cache = Class.new do
      def write(*, **)
        nil
      end
    end.new
    assert_nil ActiveJob::Debouncing::CacheStore.claim("debounce:cache_store_test:leading", expires_in: 30.seconds)
  ensure
    Object.send(:remove_const, :Rails)
    Object.const_set(:Rails, previous_rails) if previous_rails
  end

  test "debounce can be declared only once and requires an edge" do
    assert_raises ArgumentError do
      Class.new(ActiveJob::Base) do
        debounce within: 1.minute, store: STORE
        debounce within: 2.minutes, store: STORE
      end
    end

    assert_raises ArgumentError do
      Class.new(ActiveJob::Base) { debounce within: 1.minute, leading: false, trailing: false }
    end
  end

  test "instruments each debounce decision" do
    payloads = []
    record_payload = ->(*, payload) { payloads << payload }

    ActiveSupport::Notifications.subscribed record_payload, "debounce.active_job" do
      3.times { DebouncedJob.perform_later("badge") }
      FailingOpenJob.perform_later("badge")
    end

    assert_equal [ :leading, :trailing, :suppressed, :failed_open ], payloads.map { |payload| payload[:outcome] }
    assert_kind_of DebouncedJob, payloads.first[:job]
    assert_equal "debounce:debouncing_test/debounced_job:badge:leading", payloads.first[:key]
    assert_equal "debounce:debouncing_test/debounced_job:badge:trailing", payloads.third[:key]
  end
end
