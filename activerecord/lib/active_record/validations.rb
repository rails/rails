module ActiveRecord
  # = Active Record Validations
  #
  # Raised by <tt>save!</tt> and <tt>create!</tt> when the record is invalid.  Use the
  # +record+ method to retrieve the record which did not validate.
  #
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
    def save(options={})
      perform_validations(options) ? super : false
    end

    # Attempts to save the record just like Base#save but will raise a RecordInvalid exception instead of returning false
    # if the record is not valid.
    def save!(options={})
      perform_validations(options) ? super : raise(RecordInvalid.new(self))
    end

    # Runs all the specified validations and returns true if no errors were added otherwise false.
    def valid?(context = nil)
      context ||= (new_record? ? :create : :update)
      output = super(context)

      deprecated_callback_method(:validate)
      deprecated_callback_method(:"validate_on_#{context}")

      errors.empty? && output
    end

  protected

    def perform_validations(options={})
      perform_validation = case options
      when Hash
        options[:validate] != false
      else
        ActiveSupport::Deprecation.warn "save(#{options}) is deprecated, please give save(:validate => #{options}) instead", caller
        options
      end

      if perform_validation
        valid?(options.is_a?(Hash) ? options[:context] : nil)
      else
        true
      end
    end
  end
end

require "active_record/validations/associated"
require "active_record/validations/uniqueness"
