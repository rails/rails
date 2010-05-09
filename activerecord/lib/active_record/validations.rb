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

    # The validation process on save can be skipped by passing false. The regular Base#save method is
    # replaced with this when the validations module is mixed in, which it is by default.
    def save(options=nil)
      return super if valid?(options)
      false
    end

    def save_without_validation!
      save!(:validate => false)
    end

    # Attempts to save the record just like Base#save but will raise a RecordInvalid exception instead of returning false
    # if the record is not valid.
    def save!(options = nil)
      return super if valid?(options)
      raise RecordInvalid.new(self)
    end

    # Runs all the specified validations and returns true if no errors were added otherwise false.
    def valid?(options = nil)
      perform_validation = case options
        when NilClass
          true
        when Hash
          options[:validate] != false
        else
          ActiveSupport::Deprecation.warn "save(#{options}) is deprecated, please give save(:validate => #{options}) instead", caller
          options
      end

      if perform_validation
        errors.clear

        self.validation_context = new_record? ? :create : :update
        _run_validate_callbacks

        deprecated_callback_method(:validate)

        if new_record?
          deprecated_callback_method(:validate_on_create)
        else
          deprecated_callback_method(:validate_on_update)
        end

        errors.empty?
      else
        true
      end
    end
  end
end

require "active_record/validations/associated"
require "active_record/validations/uniqueness"
