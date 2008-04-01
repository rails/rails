module ActiveModel
  module Validations
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send!(:include, ActiveSupport::Callbacks)

      %w( validate validate_on_create validate_on_update ).each do |validation_method|
        base.class_eval <<-"end_eval"
          def self.#{validation_method}(*methods, &block)
            methods = CallbackChain.build(:#{validation_method}, *methods, &block)
            self.#{validation_method}_callback_chain.replace(#{validation_method}_callback_chain | methods)
          end

          def self.#{validation_method}_callback_chain
            if chain = read_inheritable_attribute(:#{validation_method})
              return chain
            else
              write_inheritable_attribute(:#{validation_method}, CallbackChain.new)
              return #{validation_method}_callback_chain
            end
          end
        end_eval
      end
    end

    module ClassMethods
      DEFAULT_VALIDATION_OPTIONS = { :on => :save, :allow_nil => false, :allow_blank => false, :message => nil }.freeze

      # Adds a validation method or block to the class. This is useful when
      # overriding the #validate instance method becomes too unwieldly and
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
      # This usage applies to #validate_on_create and #validate_on_update as well.

      # Validates each attribute against a block.
      #
      #   class Person < ActiveRecord::Base
      #     validates_each :first_name, :last_name do |record, attr, value|
      #       record.errors.add attr, 'starts with z.' if value[0] == ?z
      #     end
      #   end
      #
      # Options:
      # * <tt>on</tt> - Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>allow_nil</tt> - Skip validation if attribute is nil.
      # * <tt>allow_blank</tt> - Skip validation if attribute is blank.
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. :unless => :skip_validation, or :unless => Proc.new { |user| user.signup_step <= 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_each(*attrs)
        options = attrs.extract_options!.symbolize_keys
        attrs   = attrs.flatten

        # Declare the validation.
        send(validation_method(options[:on] || :save), options) do |record|
          attrs.each do |attr|
            value = record.send(attr)
            next if (value.nil? && options[:allow_nil]) || (value.blank? && options[:allow_blank])
            yield record, attr, value
          end
        end
      end

      private
        def validation_method(on)
          case on
            when :save   then :validate
            when :create then :validate_on_create
            when :update then :validate_on_update
          end
        end
    end

    # Returns the Errors object that holds all information about attribute error messages.
    def errors
      @errors ||= Errors.new
    end

    # Runs all the specified validations and returns true if no errors were added otherwise false.
    def valid?
      errors.clear

      run_callbacks(:validate)
      
      if responds_to?(:validate)
        ActiveSupport::Deprecations.warn "Base#validate has been deprecated, please use Base.validate :method instead"
        validate
      end

      if new_record?
        run_callbacks(:validate_on_create)

        if responds_to?(:validate_on_create)
          ActiveSupport::Deprecations.warn(
            "Base#validate_on_create has been deprecated, please use Base.validate_on_create :method instead")
          validate_on_create
        end
      else
        run_callbacks(:validate_on_update)

        if responds_to?(:validate_on_update)
          ActiveSupport::Deprecations.warn(
            "Base#validate_on_update has been deprecated, please use Base.validate_on_update :method instead")
          validate_on_update
        end
      end

      errors.empty?
    end
  end
end

Dir[File.dirname(__FILE__) + "/validations/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "active_model/validations/#{filename}"
end