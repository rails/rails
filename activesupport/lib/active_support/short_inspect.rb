module ActiveSupport
  module ShortInspect

    # Override the default inspect to strip out instance variables. This
    # is useful on large classes (such as Rails::Engine and AbstractController)
    # which would normally have kilobytes of data in their inspect output.
    # This not only obscures other debug output, but takes a long time to
    # generate.
    def inspect
      # The default output contains an identifier which is inaccessible
      # without dropping into C or other extension code (you may think it's
      # #object_id but it isn't), so we would have to mangle super rather than
      # constructing the string ourselves in order to replicate it.
      #
      # We don't want to do this though because part of the problem with
      # long inspects is the time it takes to generate them, so instead
      # we just include the object id.
      "#<%s:%i>" % [self.class.to_s, object_id]
    end

  end
end
