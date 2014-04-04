class Object
  # If receives some arguments:
  # invokes the public method whose name goes as first argument just like
  # +public_send+ does,
  # except if first argument is nil it returns receiver itself.
  #
  # Also can be called with block only (and no arguments).
  # In this case method returns result of block call (whith receiver as block argument)
  # or receiver itself (if block returns nil or false).
  #
  # Method is intended for creating conditional method chains, e.g.:
  #
  #   "test".reverse.next.concat("45").tie((:upcase if do_upcase?))
  #
  # or
  #
  #   "test".reverse.next.concat("45").tie {|s| s.upcase if do_upcase? }
  #
  # instead of
  #
  #   if do_upcase?
  #     "test".reverse.next.concat("45").upcase
  #   else
  #     "test".reverse.next.concat("45")
  #   end
  #
  # or
  #
  #   s = "test".reverse.next.concat("45")
  #   s = s.upcase if do_upcase?
  #   s
  #
  # Raises ArgumentError if called without any arguments and without block.
  def tie(*args, &block)
    if args.size > 0
      if args.first.nil?
        self
      else
        self.public_send(*args, &block)
      end
    elsif block_given?
      yield(self) || self
    else
      raise ArgumentError, "#{self.class}#tie method requires any arguments or block"
    end
  end
end
