module Rails
  module Generator

    # Manifest captures the actions a generator performs.  Instantiate
    # a manifest with an optional target object, hammer it with actions,
    # then replay or rewind on the object of your choice.
    #
    # Example:
    #   manifest = Manifest.new { |m|
    #     m.make_directory '/foo'
    #     m.create_file '/foo/bar.txt'
    #   }
    #   manifest.replay(creator)
    #   manifest.rewind(destroyer)
    class Manifest
      attr_reader :target

      # Take a default action target.  Yield self if block given.
      def initialize(target = nil)
        @target, @actions = target, []
        yield self if block_given?
      end

      # Record an action.
      def method_missing(action, *args, &block)
        @actions << [action, args, block]
      end

      # Replay recorded actions.
      def replay(target = nil)
        send_actions(target || @target, @actions)
      end

      # Rewind recorded actions.
      def rewind(target = nil)
        send_actions(target || @target, @actions.reverse)
      end

      # Erase recorded actions.
      def erase
        @actions = []
      end

      private
        def send_actions(target, actions)
          actions.each do |method, args, block|
            target.send(method, *args, &block)
          end
        end
    end

  end
end
