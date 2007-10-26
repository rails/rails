module ActiveSupport
  module Testing
    module Default
      def run(*args)
        return if method_name == :default_test
        super
      end
    end
  end
end

