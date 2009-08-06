require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/keys'
require 'active_support/concern'
require 'active_support/callbacks'

module ActiveModel
  module Validations
    extend ActiveSupport::Concern
    include ActiveSupport::Callbacks

    included do
      define_callbacks :validate
    end

    module ClassMethods
      # Adds a validation method or block to the class. This is useful when
      # overriding the +validate+ instance method becomes too unwieldly and
      # you're looking for more descriptive declaration of your validations.
      #
      # This can be done with a symbol pointing to a method:
      #
      #   class Comment < ActiveRecord::Base
      #     validate :must_be_friends
      #
      #     def must_be_friends
      #       errors.add_to_base("Must be friends to leave a comment") unless commenter.friend_of?(commentee)
      #     end
      #   end
      #
      # Or with a block which is passed the current record to be validated:
      #
      #   class Comment < ActiveRecord::Base
      #     validate do |comment|
      #       comment.must_be_friends
      #     end
      #
      #     def must_be_friends
      #       errors.add_to_base("Must be friends to leave a comment") unless commenter.friend_of?(commentee)
      #     end
      #   end
      #
      # This usage applies to +validate_on_create+ and +validate_on_update as well+.

      # Validates each attribute against a block.
      #
      #   class Person < ActiveRecord::Base
      #     validates_each :first_name, :last_name do |record, attr, value|
      #       record.errors.add attr, 'starts with z.' if value[0] == ?z
      #     end
      #   end
      #
      # Options:
      # * <tt>:on</tt> - Specifies when this validation is active (default is <tt>:save</tt>, other options <tt>:create</tt>, <tt>:update</tt>).
      # * <tt>:allow_nil</tt> - Skip validation if attribute is +nil+.
      # * <tt>:allow_blank</tt> - Skip validation if attribute is blank.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_each(*attrs)
        options = attrs.extract_options!.symbolize_keys
        attrs   = attrs.flatten

        # Declare the validation.
        send(validation_method(options[:on]), options) do |record|
          attrs.each do |attr|
            value = record.send(:read_attribute_for_validation, attr)
            next if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
            yield record, attr, value
          end
        end
      end

      private
        def validation_method(on)
          :validate
        end
    end

    # Returns the Errors object that holds all information about attribute error messages.
    def errors
      @errors ||= Errors.new(self)
    end

    # Runs all the specified validations and returns true if no errors were added otherwise false.
    def valid?
      errors.clear
      run_callbacks(:validate)
      errors.empty?
    end

    # Performs the opposite of <tt>valid?</tt>. Returns true if errors were added, false otherwise.
    def invalid?
      !valid?
    end
    
    protected
      # Hook method defining how an attribute value should be retieved. By default this is assumed
      # to be an instance named after the attribute. Override this method in subclasses should you
      # need to retrieve the value for a given attribute differently e.g.
      #   class MyClass
      #     include ActiveModel::Validations
      #
      #     def initialize(data = {})
      #       @data = data
      #     end
      #     
      #     private
      #     
      #     def read_attribute_for_validation(key)
      #       @data[key]
      #     end
      #   end
      #
      def read_attribute_for_validation(key)
        send(key)
      end
  end
end

Dir[File.dirname(__FILE__) + "/validations/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "active_model/validations/#{filename}"
end
