require 'active_support/concern'

module ActiveRecord
  # This module allows configuration options to be specified in a way such that
  # ActiveRecord::Base and ActiveRecord::Model will have access to the same value,
  # and will automatically get the appropriate readers and writers defined.
  #
  # In the future, we should probably move away from defining global config
  # directly on ActiveRecord::Base / ActiveRecord::Model.
  module Configuration #:nodoc:
    extend ActiveSupport::Concern

    module ClassMethods
    end

    def self.define(name, default = nil)
      singleton_class.send(:attr_accessor, name)

      [self, ClassMethods].each do |klass|
        klass.class_eval <<-CODE, __FILE__, __LINE__
          def #{name}
            ActiveRecord::Configuration.#{name}
          end
        CODE
      end

      ClassMethods.class_eval <<-CODE, __FILE__, __LINE__
        def #{name}=(val)
          ActiveRecord::Configuration.#{name} = val
        end
      CODE

      send("#{name}=", default) unless default.nil?
    end
  end
end
