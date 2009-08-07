require 'active_support/core_ext/string/inflections'

module ActiveModel
  class Errors < Hash
    include DeprecatedErrorMethods

    def initialize(base)
      @base = base
      super()
    end

    alias_method :get, :[]
    alias_method :set, :[]=

    def [](attribute)
      if errors = get(attribute.to_sym)
        errors
      else
        set(attribute.to_sym, [])
      end
    end

    def []=(attribute, error)
      self[attribute.to_sym] << error
    end

    def each
      each_key do |attribute|
        self[attribute].each { |error| yield attribute, error }
      end
    end

    def size
      values.flatten.size
    end

    def to_a
      full_messages
    end

    def count
      to_a.size
    end

    def to_xml(options={})
      require 'builder' unless defined? ::Builder
      options[:root]    ||= "errors"
      options[:indent]  ||= 2
      options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])

      options[:builder].instruct! unless options.delete(:skip_instruct)
      options[:builder].errors do |e|
        to_a.each { |error| e.error(error) }
      end
    end

    # Adds an error message (+messsage+) to the +attribute+, which will be returned on a call to <tt>on(attribute)</tt>
    # for the same attribute and ensure that this error object returns false when asked if <tt>empty?</tt>. More than one
    # error can be added to the same +attribute+ in which case an array will be returned on a call to <tt>on(attribute)</tt>.
    # If no +messsage+ is supplied, :invalid is assumed.
    # If +message+ is a Symbol, it will be translated, using the appropriate scope (see translate_error).
    def add(attribute, message = nil, options = {})
      message ||= :invalid
      message = generate_message(attribute, message, options) if message.is_a?(Symbol)
      self[attribute] << message
    end

    # Will add an error message to each of the attributes in +attributes+ that is empty.
    def add_on_empty(attributes, custom_message = nil)
      [attributes].flatten.each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        is_empty = value.respond_to?(:empty?) ? value.empty? : false
        add(attribute, :empty, :default => custom_message) unless !value.nil? && !is_empty
      end
    end

    # Will add an error message to each of the attributes in +attributes+ that is blank (using Object#blank?).
    def add_on_blank(attributes, custom_message = nil)
      [attributes].flatten.each do |attribute|
        value = @base.send(:read_attribute_for_validation, attribute)
        add(attribute, :blank, :default => custom_message) if value.blank?
      end
    end

    # Returns all the full error messages in an array.
    #
    #   class Company
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
          attr_name = attribute.to_s.humanize
          prefix = attr_name + I18n.t('activemodel.errors.format.separator', :default => ' ')
          messages.each do |m|
            full_messages <<  "#{prefix}#{m}"
          end
        end
      end

      full_messages
    end

    # Translates an error message in it's default scope (<tt>activemodel.errrors.messages</tt>).
    # Error messages are first looked up in <tt>models.MODEL.attributes.ATTRIBUTE.MESSAGE</tt>, if it's not there,
    # it's looked up in <tt>models.MODEL.MESSAGE</tt> and if that is not there it returns the translation of the
    # default message (e.g. <tt>activemodel.errors.messages.MESSAGE</tt>). The translated model name,
    # translated attribute name and the value are available for interpolation.
    #
    # When using inheritence in your models, it will check all the inherited models too, but only if the model itself
    # hasn't been found. Say you have <tt>class Admin < User; end</tt> and you wanted the translation for the <tt>:blank</tt>
    # error +message+ for the <tt>title</tt> +attribute+, it looks for these translations:
    #
    # <ol>
    # <li><tt>activemodel.errors.models.admin.attributes.title.blank</tt></li>
    # <li><tt>activemodel.errors.models.admin.blank</tt></li>
    # <li><tt>activemodel.errors.models.user.attributes.title.blank</tt></li>
    # <li><tt>activemodel.errors.models.user.blank</tt></li>
    # <li><tt>activemodel.errors.messages.blank</tt></li>
    # <li>any default you provided through the +options+ hash (in the activemodel.errors scope)</li>
    # </ol>
    def generate_message(attribute, message = :invalid, options = {})
      message, options[:default] = options[:default], message if options[:default].is_a?(Symbol)

      klass_ancestors = [@base.class]
      klass_ancestors += @base.class.ancestors.reject {|x| x.is_a?(Module)}

      defaults = klass_ancestors.map do |klass|
        [ :"models.#{klass.name.underscore}.attributes.#{attribute}.#{message}",
          :"models.#{klass.name.underscore}.#{message}" ]
      end

      defaults << options.delete(:default)
      defaults = defaults.compact.flatten << :"messages.#{message}"

      key = defaults.shift
      value = @base.send(:read_attribute_for_validation, attribute)

      options = { :default => defaults,
        :model => @base.class.name.humanize,
        :attribute => attribute.to_s.humanize,
        :value => value,
        :scope => [:activemodel, :errors]
      }.merge(options)

      I18n.translate(key, options)
    end
  end
end
