# frozen_string_literal: true

require "active_support/core_ext/module/redefine_method"
require "active_support/core_ext/time/calculations"
require "concurrent/map"

module ActiveSupport
  module Testing
    class SimpleStubs # :nodoc:
      Stub = Struct.new(:object, :method_name, :original_method)

      def initialize
        @stubs = Concurrent::Map.new { |h, k| h[k] = {} }
      end

      def stub_object(object, method_name, &block)
        if stub = stubbing(object, method_name)
          unstub_object(stub)
        end

        new_name = "__simple_stub__#{method_name}"

        @stubs[object.object_id][method_name] = Stub.new(object, method_name, new_name)

        object.singleton_class.send :alias_method, new_name, method_name
        object.define_singleton_method(method_name, &block)
      end

      def unstub_all!
        @stubs.each_value do |object_stubs|
          object_stubs.each_value do |stub|
            unstub_object(stub)
          end
        end
        @stubs.clear
      end

      def stubbing(object, method_name)
        @stubs[object.object_id][method_name]
      end

      private

        def unstub_object(stub)
          singleton_class = stub.object.singleton_class
          singleton_class.send :silence_redefinition_of_method, stub.method_name
          singleton_class.send :alias_method, stub.method_name, stub.original_method
          singleton_class.send :undef_method, stub.original_method
        end
    end

    # Contains helpers that help you test passage of time.
    module TimeHelpers
      def after_teardown
        travel_back
        super
      end

      # Changes current time to the time in the future or in the past by a given time difference by
      # stubbing +Time.now+, +Date.today+, and +DateTime.now+. The stubs are automatically removed
      # at the end of the test.
      #
      #   Time.current     # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   travel 1.day
      #   Time.current     # => Sun, 10 Nov 2013 15:34:49 EST -05:00
      #   Date.current     # => Sun, 10 Nov 2013
      #   DateTime.current # => Sun, 10 Nov 2013 15:34:49 -0500
      #
      # This method also accepts a block, which will return the current time back to its original
      # state at the end of the block:
      #
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   travel 1.day do
      #     User.create.created_at # => Sun, 10 Nov 2013 15:34:49 EST -05:00
      #   end
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      def travel(duration, &block)
        travel_to Time.now + duration, &block
      end

      # Changes current time to the given time by stubbing +Time.now+,
      # +Date.today+, and +DateTime.now+ to return the time or date passed into this method.
      # The stubs are automatically removed at the end of the test.
      #
      #   Time.current     # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   travel_to Time.zone.local(2004, 11, 24, 01, 04, 44)
      #   Time.current     # => Wed, 24 Nov 2004 01:04:44 EST -05:00
      #   Date.current     # => Wed, 24 Nov 2004
      #   DateTime.current # => Wed, 24 Nov 2004 01:04:44 -0500
      #
      # Dates are taken as their timestamp at the beginning of the day in the
      # application time zone. <tt>Time.current</tt> returns said timestamp,
      # and <tt>Time.now</tt> its equivalent in the system time zone. Similarly,
      # <tt>Date.current</tt> returns a date equal to the argument, and
      # <tt>Date.today</tt> the date according to <tt>Time.now</tt>, which may
      # be different. (Note that you rarely want to deal with <tt>Time.now</tt>,
      # or <tt>Date.today</tt>, in order to honor the application time zone
      # please always use <tt>Time.current</tt> and <tt>Date.current</tt>.)
      #
      # Note that the usec for the time passed will be set to 0 to prevent rounding
      # errors with external services, like MySQL (which will round instead of floor,
      # leading to off-by-one-second errors).
      #
      # This method also accepts a block, which will return the current time back to its original
      # state at the end of the block:
      #
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   travel_to Time.zone.local(2004, 11, 24, 01, 04, 44) do
      #     Time.current # => Wed, 24 Nov 2004 01:04:44 EST -05:00
      #   end
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      def travel_to(date_or_time)
        if block_given? && simple_stubs.stubbing(Time, :now)
          travel_to_nested_block_call = <<~MSG

      Calling `travel_to` with a block, when we have previously already made a call to `travel_to`, can lead to confusing time stubbing.

      Instead of:

         travel_to 2.days.from_now do
           # 2 days from today
           travel_to 3.days.from_now do
             # 5 days from today
           end
         end

      preferred way to achieve above is:

         travel 2.days do
           # 2 days from today
         end

         travel 5.days do
           # 5 days from today
         end

          MSG
          raise travel_to_nested_block_call
        end

        if date_or_time.is_a?(Date) && !date_or_time.is_a?(DateTime)
          now = date_or_time.midnight.to_time
        else
          now = date_or_time.to_time.change(usec: 0)
        end

        simple_stubs.stub_object(Time, :now) { at(now.to_i) }
        simple_stubs.stub_object(Date, :today) { jd(now.to_date.jd) }
        simple_stubs.stub_object(DateTime, :now) { jd(now.to_date.jd, now.hour, now.min, now.sec, Rational(now.utc_offset, 86400)) }

        if block_given?
          begin
            yield
          ensure
            travel_back
          end
        end
      end

      # Returns the current time back to its original state, by removing the stubs added by
      # +travel+ and +travel_to+.
      #
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   travel_to Time.zone.local(2004, 11, 24, 01, 04, 44)
      #   Time.current # => Wed, 24 Nov 2004 01:04:44 EST -05:00
      #   travel_back
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      def travel_back
        simple_stubs.unstub_all!
      end

      # Calls +travel_to+ with +Time.now+.
      #
      #   Time.current # => Sun, 09 Jul 2017 15:34:49 EST -05:00
      #   freeze_time
      #   sleep(1)
      #   Time.current # => Sun, 09 Jul 2017 15:34:49 EST -05:00
      #
      # This method also accepts a block, which will return the current time back to its original
      # state at the end of the block:
      #
      #   Time.current # => Sun, 09 Jul 2017 15:34:49 EST -05:00
      #   freeze_time do
      #     sleep(1)
      #     User.create.created_at # => Sun, 09 Jul 2017 15:34:49 EST -05:00
      #   end
      #   Time.current # => Sun, 09 Jul 2017 15:34:50 EST -05:00
      def freeze_time(&block)
        travel_to Time.now, &block
      end

      private

        def simple_stubs
          @simple_stubs ||= SimpleStubs.new
        end
    end
  end
end
