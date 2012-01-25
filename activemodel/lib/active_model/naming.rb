require 'active_support/inflector'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/module/introspection'
require 'active_support/deprecation'

module ActiveModel
  class Name < String
    attr_reader :singular, :plural, :element, :collection, :partial_path,
      :singular_route_key, :route_key, :param_key, :i18n_key

    alias_method :cache_key, :collection

    deprecate :partial_path => "ActiveModel::Name#partial_path is deprecated. Call #to_partial_path on model instances directly instead."

    def initialize(klass, namespace = nil, name = nil)
      name ||= klass.name

      raise ArgumentError, "Class name cannot be blank. You need to supply a name argument when anonymous class given" if name.blank?

      super(name)

      @unnamespaced = self.sub(/^#{namespace.name}::/, '') if namespace
      @klass        = klass
      @singular     = _singularize(self).freeze
      @plural       = ActiveSupport::Inflector.pluralize(@singular).freeze
      @element      = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(self)).freeze
      @human        = ActiveSupport::Inflector.humanize(@element).freeze
      @collection   = ActiveSupport::Inflector.tableize(self).freeze
      @partial_path = "#{@collection}/#{@element}".freeze
      @param_key    = (namespace ? _singularize(@unnamespaced) : @singular).freeze
      @i18n_key     = self.underscore.to_sym

      @route_key          = (namespace ? ActiveSupport::Inflector.pluralize(@param_key) : @plural.dup)
      @singular_route_key = ActiveSupport::Inflector.singularize(@route_key).freeze
      @route_key << "_index" if @plural == @singular
      @route_key.freeze
    end

    # Transform the model name into a more humane format, using I18n. By default,
    # it will underscore then humanize the class name
    #
    #   BlogPost.model_name.human # => "Blog post"
    #
    # Specify +options+ with additional translating options.
    def human(options={})
      return @human unless @klass.respond_to?(:lookup_ancestors) &&
                           @klass.respond_to?(:i18n_scope)

      defaults = @klass.lookup_ancestors.map do |klass|
        klass.model_name.i18n_key
      end

      defaults << options[:default] if options[:default]
      defaults << @human

      options = {:scope => [@klass.i18n_scope, :models], :count => 1, :default => defaults}.merge(options.except(:default))
      I18n.translate(defaults.shift, options)
    end

    private

    def _singularize(string, replacement='_')
      ActiveSupport::Inflector.underscore(string).tr('/', replacement)
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
  #   BookCover.model_name        # => "BookCover"
  #   BookCover.model_name.human  # => "Book cover"
  #
  #   BookCover.model_name.i18n_key              # => :book_cover
  #   BookModule::BookCover.model_name.i18n_key  # => :"book_module/book_cover"
  #
  # Providing the functionality that ActiveModel::Naming provides in your object
  # is required to pass the Active Model Lint test. So either extending the provided
  # method below, or rolling your own is required.
  module Naming
    # Returns an ActiveModel::Name object for module. It can be
    # used to retrieve all kinds of naming-related information.
    def model_name
      @_model_name ||= begin
        namespace = self.parents.detect do |n|
          n.respond_to?(:use_relative_model_naming?) && n.use_relative_model_naming?
        end
        ActiveModel::Name.new(self, namespace)
      end
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

    # Returns string to use while generating route names. It differs for
    # namespaced models regarding whether it's inside isolated engine.
    #
    # For isolated engine:
    # ActiveModel::Naming.route_key(Blog::Post) #=> post
    #
    # For shared engine:
    # ActiveModel::Naming.route_key(Blog::Post) #=> blog_post
    def self.singular_route_key(record_or_class)
      model_name_from_record_or_class(record_or_class).singular_route_key
    end

    # Returns string to use while generating route names. It differs for
    # namespaced models regarding whether it's inside isolated engine.
    #
    # For isolated engine:
    # ActiveModel::Naming.route_key(Blog::Post) #=> posts
    #
    # For shared engine:
    # ActiveModel::Naming.route_key(Blog::Post) #=> blog_posts
    #
    # The route key also considers if the noun is uncountable and, in
    # such cases, automatically appends _index.
    def self.route_key(record_or_class)
      model_name_from_record_or_class(record_or_class).route_key
    end

    # Returns string to use for params names. It differs for
    # namespaced models regarding whether it's inside isolated engine.
    #
    # For isolated engine:
    # ActiveModel::Naming.param_key(Blog::Post) #=> post
    #
    # For shared engine:
    # ActiveModel::Naming.param_key(Blog::Post) #=> blog_post
    def self.param_key(record_or_class)
      model_name_from_record_or_class(record_or_class).param_key
    end

    private
      def self.model_name_from_record_or_class(record_or_class)
        (record_or_class.is_a?(Class) ? record_or_class : convert_to_model(record_or_class).class).model_name
      end

      def self.convert_to_model(object)
        object.respond_to?(:to_model) ? object.to_model : object
      end
  end

end
