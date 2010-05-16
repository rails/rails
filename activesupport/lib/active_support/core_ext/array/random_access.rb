module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module RandomAccess
        # This method is deprecated because it masks Kernel#rand within the Array class itself, 
        # which may be used by a 3rd party library extending Array in turn. See
        #
        #   https://rails.lighthouseapp.com/projects/8994-ruby-on-rails/tickets/4555
        #
        def rand # :nodoc:
          ActiveSupport::Deprecation.warn 'Array#rand is deprecated and will be removed in Rails 3. Use "random_element" instead', caller
          random_element
        end

        # Returns a random element from the array.
        def random_element
          self[Kernel.rand(length)]
        end
      end
    end
  end
end
