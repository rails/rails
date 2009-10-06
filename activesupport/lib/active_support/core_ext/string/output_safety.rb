module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      module OutputSafety
        def self.included(base)
          base.class_eval do
            alias_method :add_without_safety, :+
            alias_method :+, :add_with_safety
            alias_method_chain :concat, :safety
            undef_method :<<
            alias_method :<<, :concat_with_safety
          end
        end

        def html_safe?
          defined?(@_rails_html_safe) && @_rails_html_safe
        end

        def html_safe!
          @_rails_html_safe = true
          self
        end

        def add_with_safety(other)
          result = add_without_safety(other)
          if html_safe? && also_html_safe?(other)
            result.html_safe!
          else
            result
          end
        end

        def concat_with_safety(other_or_fixnum)
          result = concat_without_safety(other_or_fixnum)
          unless html_safe? && also_html_safe?(other_or_fixnum)
            @_rails_html_safe = false
          end
          result
        end

        private
          def also_html_safe?(other)
            other.respond_to?(:html_safe?) && other.html_safe?
          end
      end
    end
  end
end