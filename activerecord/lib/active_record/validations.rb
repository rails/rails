module ActiveRecord
  # Raised by <tt>save!</tt> and <tt>create!</tt> when the record is invalid.  Use the
  # +record+ method to retrieve the record which did not validate.
  #   begin
  #     complex_operation_that_calls_save!_internally
  #   rescue ActiveRecord::RecordInvalid => invalid
  #     puts invalid.record.errors
  #   end
  class RecordInvalid < ActiveRecordError
    attr_reader :record
    def initialize(record)
      @record = record
      errors = @record.errors.full_messages.join(", ")
      super(I18n.t("activerecord.errors.messages.record_invalid", :errors => errors))
    end
  end

  module Validations
    extend ActiveSupport::Concern
    include ActiveModel::Validations

    included do
      alias_method_chain :save, :validation
      alias_method_chain :save!, :validation
    end

    module ClassMethods
      # Creates an object just like Base.create but calls save! instead of save
      # so an exception is raised if the record is invalid.
      def create!(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create!(attr, &block) }
        else
          object = new(attributes)
          yield(object) if block_given?
          object.save!
          object
        end
      end
    end

    module InstanceMethods
      # The validation process on save can be skipped by passing false. The regular Base#save method is
      # replaced with this when the validations module is mixed in, which it is by default.
      def save_with_validation(options=nil)
        perform_validation = case options
          when NilClass
            true
          when Hash
            options[:validate] != false
          else
            ActiveSupport::Deprecation.warn "save(#{options}) is deprecated, please give save(:validate => #{options}) instead", caller
            options
        end

        if perform_validation && valid? || !perform_validation
          save_without_validation
        else
          false
        end
      end

      # Attempts to save the record just like Base#save but will raise a RecordInvalid exception instead of returning false
      # if the record is not valid.
      def save_with_validation!
        if valid?
          save_without_validation!
        else
          raise RecordInvalid.new(self)
        end
      end

      # Runs all the specified validations and returns true if no errors were added otherwise false.
      def valid?
        errors.clear

        @_on_validate = new_record? ? :create : :update
        _run_validate_callbacks

        deprecated_callback_method(:validate)

        if new_record?
          deprecated_callback_method(:validate_on_create)
        else
          deprecated_callback_method(:validate_on_update)
        end

        errors.empty?
      end
    end
  end
end

Dir[File.dirname(__FILE__) + "/validations/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "active_record/validations/#{filename}"
end
