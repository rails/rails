module ActiveSupport
  module Testing
    class SimpleStubs # :nodoc:
      Stub = Struct.new(:object, :method_name, :original_method)

      def initialize
        @stubs = {}
      end

      def stub_object(object, method_name, return_value)
        key = [object.object_id, method_name]

        if (stub = @stubs[key])
          unstub_object(stub)
        end

        new_name = "__simple_stub__#{method_name}"

        @stubs[key] = Stub.new(object, method_name, new_name)

        object.singleton_class.send :alias_method, new_name, method_name
        object.define_singleton_method(method_name) { return_value }
      end

      def unstub_all!
        @stubs.each_value do |stub|
          unstub_object(stub)
        end
        @stubs = {}
      end

      private

        def unstub_object(stub)
          singleton_class = stub.object.singleton_class
          singleton_class.send :undef_method, stub.method_name
          singleton_class.send :alias_method, stub.method_name, stub.original_method
          singleton_class.send :undef_method, stub.original_method
        end
    end

    # Containing helpers that helps you test passage of time.
    module TimeHelpers
      def after_teardown #:nodoc:
        simple_stubs.unstub_all!
        super
      end

      # Change current time to the time in the future or in the past by a given time difference by
      # stubbing +Time.now+ and +Date.today+. Note that the stubs are automatically removed
      # at the end of each test.
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
      # time or date passed into this method. Note that the stubs are automatically removed
      # at the end of each test.
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
        simple_stubs.stub_object(Time, :now, date_or_time.to_time)
        simple_stubs.stub_object(Date, :today, date_or_time.to_date)

        if block_given?
          block.call
          simple_stubs.unstub_all!
        end
      end

      private

        def simple_stubs
          @simple_stubs ||= SimpleStubs.new
        end
    end
  end
end
