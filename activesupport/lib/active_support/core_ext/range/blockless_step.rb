require 'active_support/core_ext/module/aliasing'

class Range
  begin
    (1..2).step
  # Range#step doesn't return an Enumerator
  rescue LocalJumpError
    # Return an array when step is called without a block.
    def step_with_blockless(*args, &block)
      if block_given?
        step_without_blockless(*args, &block)
      else
        array = []
        step_without_blockless(*args) { |step| array << step }
        array
      end
    end
  else
    def step_with_blockless(*args, &block) #:nodoc:
      if block_given?
        step_without_blockless(*args, &block)
      else
        step_without_blockless(*args).to_a
      end
    end
  end

  alias_method_chain :step, :blockless
end
