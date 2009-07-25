require 'active_support/core_ext/integer/even_odd'

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
      super("Validation failed: #{@record.errors.full_messages.join(", ")}")
    end
  end

  class Errors < ActiveModel::Errors
    class << self
      def default_error_messages
        message = "Errors.default_error_messages has been deprecated. Please use I18n.translate('activerecord.errors.messages')."
        ActiveSupport::Deprecation.warn(message)

        I18n.translate 'activerecord.errors.messages'
      end
    end

    # Returns all the full error messages in an array.
    #
    #   class Company < ActiveRecord::Base
    #     validates_presence_of :name, :address, :email
    #     validates_length_of :name, :in => 5..30
    #   end
    #
    #   company = Company.create(:address => '123 First St.')
    #   company.errors.full_messages # =>
    #     ["Name is too short (minimum is 5 characters)", "Name can't be blank", "Address can't be blank"]
    def full_messages(options = {})
      full_messages = []

      each do |attribute, messages|
        messages = Array.wrap(messages)
        next if messages.empty?

        if attribute == :base
          messages.each {|m| full_messages << m }
        else
          attr_name = @base.class.human_attribute_name(attribute.to_s)
          prefix = attr_name + I18n.t('activerecord.errors.format.separator', :default => ' ')
          messages.each do |m|
            full_messages <<  "#{prefix}#{m}"
          end
        end
      end

      full_messages
    end

    # Translates an error message in it's default scope (<tt>activerecord.errrors.messages</tt>).
    # Error messages are first looked up in <tt>models.MODEL.attributes.ATTRIBUTE.MESSAGE</tt>, if it's not there, 
    # it's looked up in <tt>models.MODEL.MESSAGE</tt> and if that is not there it returns the translation of the 
    # default message (e.g. <tt>activerecord.errors.messages.MESSAGE</tt>). The translated model name, 
    # translated attribute name and the value are available for interpolation.
    #
    # When using inheritance in your models, it will check all the inherited models too, but only if the model itself
    # hasn't been found. Say you have <tt>class Admin < User; end</tt> and you wanted the translation for the <tt>:blank</tt>
    # error +message+ for the <tt>title</tt> +attribute+, it looks for these translations:
    # 
    # <ol>
    # <li><tt>activerecord.errors.models.admin.attributes.title.blank</tt></li>
    # <li><tt>activerecord.errors.models.admin.blank</tt></li>
    # <li><tt>activerecord.errors.models.user.attributes.title.blank</tt></li>
    # <li><tt>activerecord.errors.models.user.blank</tt></li>
    # <li><tt>activerecord.errors.messages.blank</tt></li>
    # <li>any default you provided through the +options+ hash (in the activerecord.errors scope)</li>
    # </ol>
    def generate_message(attribute, message = :invalid, options = {})
      message, options[:default] = options[:default], message if options[:default].is_a?(Symbol)

      defaults = @base.class.self_and_descendants_from_active_record.map do |klass|
        [ :"models.#{klass.name.underscore}.attributes.#{attribute}.#{message}", 
          :"models.#{klass.name.underscore}.#{message}" ]
      end
      
      defaults << options.delete(:default)
      defaults = defaults.compact.flatten << :"messages.#{message}"

      key = defaults.shift
      value = @base.respond_to?(attribute) ? @base.send(attribute) : nil

      options = { :default => defaults,
        :model => @base.class.human_name,
        :attribute => @base.class.human_attribute_name(attribute.to_s),
        :value => value,
        :scope => [:activerecord, :errors]
      }.merge(options)

      I18n.translate(key, options)
    end
  end

  module Validations
    extend ActiveSupport::Concern

    include ActiveSupport::Callbacks
    include ActiveModel::Validations

    included do
      alias_method_chain :save, :validation
      alias_method_chain :save!, :validation

      define_callbacks :validate_on_create, :validate_on_update
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

      def validation_method(on)
        case on
        when :create
          :validate_on_create
        when :update
          :validate_on_update
        else
          :validate
        end
      end
    end

    module InstanceMethods
      # The validation process on save can be skipped by passing false. The regular Base#save method is
      # replaced with this when the validations module is mixed in, which it is by default.
      def save_with_validation(perform_validation = true)
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

        run_callbacks(:validate)

        if respond_to?(:validate)
          ActiveSupport::Deprecation.warn("Base#validate has been deprecated, please use Base.validate :method instead")
          validate
        end

        if new_record?
          run_callbacks(:validate_on_create)

          if respond_to?(:validate_on_create)
            ActiveSupport::Deprecation.warn("Base#validate_on_create has been deprecated, please use Base.validate_on_create :method instead")
            validate_on_create
          end
        else
          run_callbacks(:validate_on_update)

          if respond_to?(:validate_on_update)
            ActiveSupport::Deprecation.warn("Base#validate_on_update has been deprecated, please use Base.validate_on_update :method instead")
            validate_on_update
          end
        end

        errors.empty?
      end

      # Returns the Errors object that holds all information about attribute error messages.
      def errors
        @errors ||= Errors.new(self)
      end
    end
  end
end

Dir[File.dirname(__FILE__) + "/validations/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require "active_record/validations/#{filename}"
end
