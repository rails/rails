module ActiveRecord
  module ApplicationConfiguration
    extend ActiveSupport::Concern

    # The <tt>ApplicationConfiguration</tt> module allows you to control different
    # configurations that have been set on a particular namespace or model. The
    # <tt>ApplicationRecord</tt> class for a particular model can be accessed and used
    # for finding configurations.
    #
    # To access this class, you can use the <tt>application_record</tt> method on
    # any subclass of <tt>ActiveRecord::Base</tt>. For example:
    #
    #   class MyModel < ApplicationRecord
    #   end
    #
    #   ActiveRecord::Base.application_record  # => ApplicationRecord
    #   MyModel.application_record             # => ApplicationRecord
    #
    # Moreover, you can use namespacing of modules with the <tt>application_record</tt>
    # method.
    #
    #   module MyNamespace
    #     class ApplicationRecord < ::ApplicationRecord
    #     end
    #
    #     class MyModel < ApplicationRecord
    #     end
    #   end
    #
    #   ActiveRecord::Base.application_record    # => ApplicationRecord
    #   MyNamespace::MyModel.application_record  # => MyNamespace::ApplicationRecord
    #
    # You may additionally pass in a class to <tt>application_record</tt>, and
    # it will look for the configuration of that class. For example:
    #
    #   ActiveRecord::Base.application_record(MyNamespace::MyModel) 
    #       # => MyNamespace::ApplicationRecord
    #
    # If the class that is passed into <tt>application_record</tt> does not have
    # a configuration associated with it, then the method will return the value
    # that would have been returned without any argument. 
    #
    #   ActiveRecord::Base.application_record('something_with_no_config')
    #       # => ApplicationRecord
    #
    module ClassMethods
      def configs_from(mod)
        app_record = self
        define_singleton_method(:application_record) { |klass = nil| app_record }

        mod.define_singleton_method(:application_record) { |klass = nil| app_record }
      end

      def application_record(klass = nil)
        return base_app_record unless klass

        klass = klass.class unless klass.respond_to?(:parents)

        if klass.respond_to?(:application_record)
          klass.application_record
        elsif app_record = klass.parents.detect { |p| p.respond_to?(:application_record) }
          app_record
        else
          base_app_record
        end
      end

      private

        def base_app_record
          @base_app_record ||= defined?(ApplicationRecord) ? ApplicationRecord : ActiveRecord::Base
        end
    end
  end
end
