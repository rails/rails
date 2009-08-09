module ActiveModel
  module Validations
    module ClassMethods

      # Passes the record off to the class or classes specified and allows them to add errors based on more complex conditions.
      #
      #   class Person < ActiveRecord::Base
      #     validates_with MyValidator
      #   end
      #
      #   class MyValidator < ActiveRecord::Validator
      #     def validate
      #       if some_complex_logic
      #         record.errors[:base] << "This record is invalid"
      #       end
      #     end
      #
      #     private
      #       def some_complex_logic
      #         # ...
      #       end
      #   end
      #
      # You may also pass it multiple classes, like so:
      #
      #   class Person < ActiveRecord::Base
      #     validates_with MyValidator, MyOtherValidator, :on => :create
      #   end
      #
      # Configuration options:
      # * <tt>on</tt> - Specifies when this validation is active (<tt>:create</tt> or <tt>:update</tt>
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).
      #   The method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).
      #   The method, proc or string should return or evaluate to a true or false value.
      #
      # If you pass any additional configuration options, they will be passed to the class and available as <tt>options</tt>:
      #
      #   class Person < ActiveRecord::Base
      #     validates_with MyValidator, :my_custom_key => "my custom value"
      #   end
      #
      #   class MyValidator < ActiveRecord::Validator
      #     def validate
      #       options[:my_custom_key] # => "my custom value"
      #     end
      #   end
      #
      def validates_with(*args)
        configuration = args.extract_options!

        send(validation_method(configuration[:on]), configuration) do |record|
          args.each do |klass|
            klass.new(record, configuration.except(:on, :if, :unless)).validate
          end
        end
      end
    end
  end
end


