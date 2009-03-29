class Range
  if RUBY_VERSION < '1.9'
    # Return an array when step is called without a block.
    def step_with_blockless(value = 1, &block)
      if block_given?
        step_without_blockless(value, &block)
      else
        array = []
        step_without_blockless(value) { |step| array << step }
        array
      end
    end
  else
    def step_with_blockless(value = 1, &block) #:nodoc:
      if block_given?
        step_without_blockless
      else
        step_without_blockless(value).to_a
      end
    end
  end

  alias_method_chain :step, :blockless
end
