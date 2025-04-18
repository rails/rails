# frozen_string_literal: true

require "active_support/core_ext/module/redefine_method"
require "active_support/core_ext/time/calculations"

module ActiveSupport
  module Testing
    # Manages stubs for TimeHelpers
    class SimpleStubs # :nodoc:
      Stub = Struct.new(:object, :method_name, :original_method)

      def initialize
        @stubs = Hash.new { |h, k| h[k] = {} }
      end

      # Stubs object.method_name with the given block
      # If the method is already stubbed, remove that stub
      # so that removing this stub will restore the original implementation.
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   target = Time.zone.local(2004, 11, 24, 1, 4, 44)
      #   simple_stubs.stub_object(Time, :now) { at(target.to_i) }
      #   Time.current # => Wed, 24 Nov 2004 01:04:44 EST -05:00
      def stub_object(object, method_name, &block)
        if stub = stubbing(object, method_name)
          unstub_object(stub)
        end

        new_name = "__simple_stub__#{method_name}__#{object_id}"

        @stubs[object.object_id][method_name] = Stub.new(object, method_name, new_name)

        object.singleton_class.alias_method new_name, method_name
        object.define_singleton_method(method_name, &block)
      end

      # Remove all object-method stubs held by this instance
      def unstub_all!
        @stubs.each_value do |object_stubs|
          object_stubs.each_value do |stub|
            unstub_object(stub)
          end
        end
        @stubs.clear
      end

      # Returns the Stub for object#method_name
      # (nil if it is not stubbed)
      def stubbing(object, method_name)
        @stubs[object.object_id][method_name]
      end

      # Returns true if any stubs are set, false if there are none
      def stubbed?
        !@stubs.empty?
      end

      private
        # Restores the original object.method described by the Stub
        def unstub_object(stub)
          singleton_class = stub.object.singleton_class
          singleton_class.silence_redefinition_of_method stub.method_name
          singleton_class.alias_method stub.method_name, stub.original_method
          singleton_class.undef_method stub.original_method
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
      # Note that the usec for the resulting time will be set to 0 to prevent rounding
      # errors with external services, like MySQL (which will round instead of floor,
      # leading to off-by-one-second errors), unless the <tt>with_usec</tt> argument
      # is set to <tt>true</tt>.
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
      def travel(duration, with_usec: false, &block)
        travel_to Time.now + duration, with_usec: with_usec, &block
      end

      # Changes current time to the given time by stubbing +Time.now+, +Time.new+,
      # +Date.today+, and +DateTime.now+ to return the time or date passed into this method.
      # The stubs are automatically removed at the end of the test.
      #
      #   Time.current     # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   travel_to Time.zone.local(2004, 11, 24, 1, 4, 44)
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
      # leading to off-by-one-second errors), unless the <tt>with_usec</tt> argument
      # is set to <tt>true</tt>.
      #
      # This method also accepts a block, which will return the current time back to its original
      # state at the end of the block:
      #
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   travel_to Time.zone.local(2004, 11, 24, 1, 4, 44) do
      #     Time.current # => Wed, 24 Nov 2004 01:04:44 EST -05:00
      #   end
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      def travel_to(date_or_time, with_usec: false)
        if block_given? && in_block
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
        elsif date_or_time.is_a?(String)
          now = Time.zone.parse(date_or_time)
        else
          now = date_or_time
          now = now.to_time unless now.is_a?(Time)
        end

        now = now.change(usec: 0) unless with_usec

        # +now+ must be in local system timezone, because +Time.at(now)+
        # and +now.to_date+ (see stubs below) will use +now+'s timezone too!
        now = now.getlocal

        stubs = simple_stubs
        stubbed_time = Time.now if stubs.stubbing(Time, :now)
        stubs.stub_object(Time, :now) { at(now) }

        stubs.stub_object(Time, :new) do |*args, **options|
          if args.empty? && options.empty?
            at(now)
          else
            stub = stubs.stubbing(Time, :new)
            Time.send(stub.original_method, *args, **options)
          end
        end

        stubs.stub_object(Date, :today) { jd(now.to_date.jd) }
        stubs.stub_object(DateTime, :now) { jd(now.to_date.jd, now.hour, now.min, now.sec, Rational(now.utc_offset, 86400)) }

        if block_given?
          begin
            self.in_block = true
            yield
          ensure
            if stubbed_time
              travel_to stubbed_time
            else
              travel_back
            end
            self.in_block = false
          end
        end
      end

      # Returns the current time back to its original state, by removing the stubs added by
      # +travel+, +travel_to+, and +freeze_time+.
      #
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #
      #   travel_to Time.zone.local(2004, 11, 24, 1, 4, 44)
      #   Time.current # => Wed, 24 Nov 2004 01:04:44 EST -05:00
      #
      #   travel_back
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #
      # This method also accepts a block, which brings the stubs back at the end of the block:
      #
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #
      #   travel_to Time.zone.local(2004, 11, 24, 1, 4, 44)
      #   Time.current # => Wed, 24 Nov 2004 01:04:44 EST -05:00
      #
      #   travel_back do
      #     Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   end
      #
      #   Time.current # => Wed, 24 Nov 2004 01:04:44 EST -05:00
      def travel_back
        stubbed_time = Time.current if block_given? && simple_stubs.stubbed?

        simple_stubs.unstub_all!
        yield if block_given?
      ensure
        travel_to stubbed_time if stubbed_time
      end
      alias_method :unfreeze_time, :travel_back

      # Calls +travel_to+ with +date_or_time+, which defaults to +Time.now+.
      # Forwards optional <tt>with_usec</tt> argument.
      #
      #   Time.current # => Sun, 09 Jul 2017 15:34:49 EST -05:00
      #   freeze_time
      #   sleep(1)
      #   Time.current # => Sun, 09 Jul 2017 15:34:49 EST -05:00
      #   freeze_time Time.current + 1.day
      #   sleep(1)
      #   Time.current # => Mon, 10 Jul 2017 15:34:49 EST -05:00
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
      def freeze_time(date_or_time = Time.now, with_usec: false, &block)
        travel_to date_or_time, with_usec: with_usec, &block
      end

      private
        def simple_stubs
          @simple_stubs ||= SimpleStubs.new
        end

        attr_accessor :in_block
    end
  end
end
