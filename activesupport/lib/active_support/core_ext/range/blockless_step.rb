module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Range #:nodoc:
      # Return an array when step is called without a block.
      module BlocklessStep
        def self.included(base) #:nodoc:
          base.alias_method_chain :step, :blockless
        end

        if RUBY_VERSION < '1.9'
          def step_with_blockless(value = 1, &block)
            if block_given?
              step_without_blockless(value, &block)
            else
              [].tap do |array|
                step_without_blockless(value) { |step| array << step }
              end
            end
          end
        else
          def step_with_blockless(value = 1, &block)
            if block_given?
              step_without_blockless(value, &block)
            else
              step_without_blockless(value).to_a
            end
          end
        end
      end
    end
  end
end
