module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Range #:nodoc:
      # Return and array when step is called without a block
      module BlocklessStep

        def self.included(klass) #:nodoc:
          klass.send(:alias_method, :step_with_block, :step)
          klass.send(:alias_method, :step, :step_without_block)
        end        
        
        def step_without_block(value, &block)
          if block_given?
            step_with_block(value, &block)
          else
            returning [] do |array|
              step_with_block(value) {|step| array << step }
            end
          end
        end

      end
    end
  end
end