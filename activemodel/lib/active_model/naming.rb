require 'active_support/inflector'

module ActiveModel
  class Name < String
    attr_reader :singular, :plural, :element, :collection, :partial_path
    alias_method :cache_key, :collection

    def initialize(klass)
      super(klass.name)
      @klass = klass
      @singular = ActiveSupport::Inflector.underscore(self).tr('/', '_').freeze
      @plural = ActiveSupport::Inflector.pluralize(@singular).freeze
      @element = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(self)).freeze
      @human = ActiveSupport::Inflector.humanize(@element).freeze
      @collection = ActiveSupport::Inflector.tableize(self).freeze
      @partial_path = "#{@collection}/#{@element}".freeze
    end

    # Transform the model name into a more humane format, using I18n. By default,
    # it will underscore then humanize the class name (BlogPost.model_name.human #=> "Blog post").
    # Specify +options+ with additional translating options.
    def human(options={})
      return @human unless @klass.respond_to?(:lookup_ancestors) &&
                           @klass.respond_to?(:i18n_scope)

      defaults = @klass.lookup_ancestors.map do |klass|
        klass.model_name.underscore.to_sym
      end

      defaults << options.delete(:default) if options[:default]
      defaults << @human

      options.reverse_merge! :scope => [@klass.i18n_scope, :models], :count => 1, :default => defaults
      I18n.translate(defaults.shift, options)
    end
  end

  # == Active Model Naming
  #
  # Creates a +model_name+ method on your object.
  # 
  # To implement, just extend ActiveModel::Naming in your object:
  # 
  #   class BookCover
  #     extend ActiveModel::Naming
  #   end
  # 
  #   BookCover.model_name        #=> "BookCover"
  #   BookCover.model_name.human  #=> "Book cover"
  # 
  # Providing the functionality that ActiveModel::Naming provides in your object
  # is required to pass the Active Model Lint test.  So either extending the provided
  # method below, or rolling your own is required..
  module Naming
    # Returns an ActiveModel::Name object for module. It can be
    # used to retrieve all kinds of naming-related information.
    def model_name
      @_model_name ||= ActiveModel::Name.new(self)
    end

    # Returns the plural class name of a record or class. Examples:
    #
    #   ActiveModel::Naming.plural(post)             # => "posts"
    #   ActiveModel::Naming.plural(Highrise::Person) # => "highrise_people"
    def self.plural(record_or_class)
      model_name_from_record_or_class(record_or_class).plural
    end

    # Returns the singular class name of a record or class. Examples:
    #
    #   ActiveModel::Naming.singular(post)             # => "post"
    #   ActiveModel::Naming.singular(Highrise::Person) # => "highrise_person"
    def self.singular(record_or_class)
      model_name_from_record_or_class(record_or_class).singular
    end

    # Identifies whether the class name of a record or class is uncountable. Examples:
    #
    #   ActiveModel::Naming.uncountable?(Sheep) # => true
    #   ActiveModel::Naming.uncountable?(Post) => false
    def self.uncountable?(record_or_class)
      plural(record_or_class) == singular(record_or_class)
    end

    private
      def self.model_name_from_record_or_class(record_or_class)
        (record_or_class.is_a?(Class) ? record_or_class : record_or_class.class).model_name
      end
  end
  
end
