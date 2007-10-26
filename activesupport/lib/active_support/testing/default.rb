module ActiveSupport
  module Testing
    module Default
      def run(*args)
        #method_name appears to be a symbol on 1.8.4 and a string on 1.8.6
        return if @method_name.to_s == "default_test"
        super
      end
    end
  end
end

