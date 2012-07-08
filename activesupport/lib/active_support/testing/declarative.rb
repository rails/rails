module ActiveSupport
  module Testing
    module Declarative

      def self.extended(klass) #:nodoc:
        klass.class_eval do

          unless method_defined?(:describe)
            def self.describe(text)
              class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
                def self.name
                  "#{text}"
                end
              RUBY_EVAL
            end
          end

        end
      end
    end
  end
end
