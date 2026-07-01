# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/notifications/instrumenter"

module ActiveSupport
  module Notifications
    class RactorCompatibilityTest < ActiveSupport::TestCase
      WitnessError = Class.new(StandardError)

      setup do
        @old_proc_action = ActiveSupport::Ractors.unshareable_proc_action
        ActiveSupport::Ractors.unshareable_proc_action = :raise
      end

      teardown do
        ActiveSupport::Ractors.unshareable_proc_action = @old_proc_action
      end

      test "record and set subscriptions" do
        fanout = Fanout.new
        subscription = fanout.subscribe("active_record.sql") { raise WitnessError }
        RactorCompatibility.record_subscriptions(fanout)

        fanout = Fanout.new
        RactorCompatibility.set_subscriptions(fanout)

        assert_raises(WitnessError) do
          Instrumenter.new(fanout).instrument("active_record.sql", {})
        end
      ensure
        ActiveSupport::Notifications.unsubscribe(subscription)
      end

      test "record and set subscriptions when using a regexp" do
        fanout = Fanout.new
        subscription = fanout.subscribe("active_record.sql") { }
        regexp_subscription = fanout.subscribe(/.*/) { raise WitnessError }
        RactorCompatibility.record_subscriptions(fanout)

        fanout = Fanout.new
        RactorCompatibility.set_subscriptions(fanout)

        assert_raises(WitnessError) do
          Instrumenter.new(fanout).instrument("active_record.sql", {})
        end
      ensure
        ActiveSupport::Notifications.unsubscribe(subscription)
        ActiveSupport::Notifications.unsubscribe(regexp_subscription)
      end

      if RUBY_VERSION >= "4.0"
        test "creating a subscription that's not ractor shareable raises an error" do
          fanout = Fanout.new
          outer = []

          assert_raises(Ractor::IsolationError) do
            fanout.subscribe("active_record.sql") { outer }
          end
        end
      end
    end
  end
end
