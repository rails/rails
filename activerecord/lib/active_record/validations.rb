module ActiveRecord
  # = Active Record RecordInvalid
  #
  # Raised by <tt>save!</tt> and <tt>create!</tt> when the record is invalid. Use the
  # +record+ method to retrieve the record which did not validate.
  #
  #   begin
  #     complex_operation_that_internally_calls_save!
  #   rescue ActiveRecord::RecordInvalid => invalid
  #     puts invalid.record.errors
  #   end
  class RecordInvalid < ActiveRecordError
    attr_reader :record

    def initialize(record)
      @record = record
      errors = @record.errors.full_messages.join(", ")
      super(I18n.t(:"#{@record.class.i18n_scope}.errors.messages.record_invalid", :errors => errors, :default => :"errors.messages.record_invalid"))
    end
  end

  # = Active Record Validations
  #
  # Active Record includes the majority of its validations from <tt>ActiveModel::Validations</tt>
  # all of which accept the <tt>:on</tt> argument to define the context where the
  # validations are active. Active Record will always supply either the context of
  # <tt>:create</tt> or <tt>:update</tt> dependent on whether the model is a
  # <tt>new_record?</tt>.
  module Validations
    extend ActiveSupport::Concern
    include ActiveModel::Validations

    # The validation process on save can be skipped by passing <tt>validate: false</tt>.
    # The regular Base#save method is replaced with this when the validations
    # module is mixed in, which it is by default.
    def save(options={})
      perform_validations(options) ? super : false
    end

    # Attempts to save the record just like Base#save but will raise a +RecordInvalid+
    # exception instead of returning +false+ if the record is not valid.
    def save!(options={})
      perform_validations(options) ? super : raise_record_invalid
    end

    # Runs all the validations within the specified context. Returns +true+ if
    # no errors are found, +false+ otherwise.
    #
    # Aliased as validate.
    #
    # If the argument is +false+ (default is +nil+), the context is set to <tt>:create</tt> if
    # <tt>new_record?</tt> is +true+, and to <tt>:update</tt> if it is not.
    #
    # Validations with no <tt>:on</tt> option will run no matter the context. Validations with
    # some <tt>:on</tt> option will only run in the specified context.
    def valid?(context = nil)
      context ||= (new_record? ? :create : :update)
      output = super(context)
      errors.empty? && output
    end

    alias_method :validate, :valid?

    # Runs all the validations within the specified context. Returns +true+ if
    # no errors are found, raises +RecordInvalid+ otherwise.
    #
    # If the argument is +false+ (default is +nil+), the context is set to <tt>:create</tt> if
    # <tt>new_record?</tt> is +true+, and to <tt>:update</tt> if it is not.
    #
    # Validations with no <tt>:on</tt> option will run no matter the context. Validations with
    # some <tt>:on</tt> option will only run in the specified context.
    def validate!(context = nil)
      valid?(context) || raise_record_invalid
    end

  protected

    def raise_record_invalid
      raise(RecordInvalid.new(self))
    end

    def perform_validations(options={}) # :nodoc:
      options[:validate] == false || valid?(options[:context])
    end
  end
end

require "active_record/validations/associated"
require "active_record/validations/uniqueness"
require "active_record/validations/presence"
