module ActiveSupport
  module Testing
    # Containing helpers that helps you test passage of time.
    module TimeHelpers
      # Change current time to the time in the future or in the past by a given time difference by
      # stubbing +Time.now+ and +Date.today+. This method also accepts a block, which will return
      # current time back to its original state at the end of the block.
      #
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   travel 1.day
      #   Time.current # => Sun, 10 Nov 2013 15:34:49 EST -05:00
      #   Date.current # => Sun, 10 Nov 2013
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

      # Change current time to the given time by stubbing +Time.now+ and +Date.today+ to return the
      # time or date passed into this method. This method also accepts a block, which will return
      # current time back to its original state at the end of the block.
      #
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   travel_to Time.new(2004, 11, 24, 01, 04, 44)
      #   Time.current # => Wed, 24 Nov 2004 01:04:44 EST -05:00
      #   Date.current # => Wed, 24 Nov 2004
      #
      # This method also accepts a block, which will return the current time back to its original
      # state at the end of the block:
      #
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      #   travel_to Time.new(2004, 11, 24, 01, 04, 44) do
      #     User.create.created_at # => Wed, 24 Nov 2004 01:04:44 EST -05:00
      #   end
      #   Time.current # => Sat, 09 Nov 2013 15:34:49 EST -05:00
      def travel_to(date_or_time, &block)
        Time.stubs now: date_or_time.to_time
        Date.stubs today: date_or_time.to_date

        if block_given?
          block.call
          Time.unstub :now
          Date.unstub :today
        end
      end
    end
  end
end
