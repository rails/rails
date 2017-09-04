module ActiveSupport
  module Testing
    module Context
      def context(message, &block)
        class_name = message.gsub(/\W+/, ' ').strip.split(/\s/).map(&:capitalize).join('')+'Test'

        clean_class = Class.new(self)
        clean_class.instance_methods.each do |test_method|
          clean_class.send(:undef_method, test_method) if test_method.to_s.start_with?('test_')
        end

        const_set(class_name, Class.new(clean_class, &block))
      end
    end
  end
end
