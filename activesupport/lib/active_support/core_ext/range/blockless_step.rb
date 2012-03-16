require 'active_support/core_ext/module/aliasing'

class Range
  def step_with_blockless(*args, &block) #:nodoc:
    if block_given?
      step_without_blockless(*args, &block)
    else
      step_without_blockless(*args).to_a
    end
  end

  alias_method_chain :step, :blockless
end
