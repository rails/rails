module ActiveSupport
  # Wrapping a string in this class gives you a prettier way to test
  # for equality:
  #   env = ActiveSupport::SymbolInquirer.new(:production)
  #
  #   env.production?  # => true
  #   env.development? # => false
  class SymbolInquirer < SimpleDelegator
    private

      def respond_to_missing?(method_name, include_private = false)
        method_name[-1] == '?'
      end

      def method_missing(method_name, *arguments)
        if method_name[-1] == '?'
          to_s == method_name[0..-2]
        else
          super
        end
      end
  end
end
