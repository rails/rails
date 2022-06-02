# frozen_string_literal: true

require "active_support/core_ext/hash/except"
require "active_support/core_ext/module/introspection"
require "active_support/core_ext/module/redefine_method"
require "active_support/core_ext/module/delegation"

module ActiveModel
  class Name
    include Comparable

    attr_accessor :singular, :plural, :element, :collection,
      :singular_route_key, :route_key, :param_key, :i18n_key,
      :name

    alias_method :cache_key, :collection

    ##
    # :method: ==
    #
    # :call-seq:
    #   ==(other)
    #
    # Equivalent to <tt>String#==</tt>. Returns +true+ if the class name and
    # +other+ are equal, otherwise +false+.
    #
    #   class BlogPost
    #     extend ActiveModel::Naming
    #   end
    #
    #   BlogPost.model_name == 'BlogPost'  # => true
    #   BlogPost.model_name == 'Blog Post' # => false

    ##
    # :method: ===
    #
    # :call-seq:
    #   ===(other)
    #
    # Equivalent to <tt>#==</tt>.
    #
    #   class BlogPost
    #     extend ActiveModel::Naming
    #   end
    #
    #   BlogPost.model_name === 'BlogPost'  # => true
    #   BlogPost.model_name === 'Blog Post' # => false

    ##
    # :method: <=>
    #
    # :call-seq:
    #   <=>(other)
    #
    # Equivalent to <tt>String#<=></tt>.
    #
    #   class BlogPost
    #     extend ActiveModel::Naming
    #   end
    #
    #   BlogPost.model_name <=> 'BlogPost'  # => 0
    #   BlogPost.model_name <=> 'Blog'      # => 1
    #   BlogPost.model_name <=> 'BlogPosts' # => -1

    ##
    # :method: =~
    #
    # :call-seq:
    #   =~(regexp)
    #
    # Equivalent to <tt>String#=~</tt>. Match the class name against the given
    # regexp. Returns the position where the match starts or +nil+ if there is
    # no match.
    #
    #   class BlogPost
    #     extend ActiveModel::Naming
    #   end
    #
    #   BlogPost.model_name =~ /Post/ # => 4
    #   BlogPost.model_name =~ /\d/   # => nil

    ##
    # :method: !~
    #
    # :call-seq:
    #   !~(regexp)
    #
    # Equivalent to <tt>String#!~</tt>. Match the class name against the given
    # regexp. Returns +true+ if there is no match, otherwise +false+.
    #
    #   class BlogPost
    #     extend ActiveModel::Naming
    #   end
    #
    #   BlogPost.model_name !~ /Post/ # => false
    #   BlogPost.model_name !~ /\d/   # => true

    ##
    # :method: eql?
    #
    # :call-seq:
    #   eql?(other)
    #
    # Equivalent to <tt>String#eql?</tt>. Returns +true+ if the class name and
    # +other+ have the same length and content, otherwise +false+.
    #
    #   class BlogPost
    #     extend ActiveModel::Naming
    #   end
    #
    #   BlogPost.model_name.eql?('BlogPost')  # => true
    #   BlogPost.model_name.eql?('Blog Post') # => false

    ##
    # :method: match?
    #
    # :call-seq:
    #   match?(regexp)
    #
    # Equivalent to <tt>String#match?</tt>. Match the class name against the
    # given regexp. Returns +true+ if there is a match, otherwise +false+.
    #
    #   class BlogPost
    #     extend ActiveModel::Naming
    #   end
    #
    #   BlogPost.model_name.match?(/Post/) # => true
    #   BlogPost.model_name.match?(/\d/) # => false

    ##
    # :method: to_s
    #
    # :call-seq:
    #   to_s()
    #
    # Returns the class name.
    #
    #   class BlogPost
    #     extend ActiveModel::Naming
    #   end
    #
    #   BlogPost.model_name.to_s # => "BlogPost"

    ##
    # :method: to_str
    #
    # :call-seq:
    #   to_str()
    #
    # Equivalent to +to_s+.
    delegate :==, :===, :<=>, :=~, :"!~", :eql?, :match?, :to_s,
             :to_str, :as_json, to: :name

    # Returns a new ActiveModel::Name instance. By default, the +namespace+
    # and +name+ option will take the namespace and name of the given class
    # respectively.
    # Use +locale+ argument for singularize and pluralize model name.
    #
    #   module Foo
    #     class Bar
    #     end
    #   end
    #
    #   ActiveModel::Name.new(Foo::Bar).to_s
    #   # => "Foo::Bar"
    def initialize(klass, namespace = nil, name = nil, locale = :en)
      @name = name || klass.name

      raise ArgumentError, "Class name cannot be blank. You need to supply a name argument when anonymous class given" if @name.blank?

      @unnamespaced = @name.delete_prefix("#{namespace.name}::") if namespace
      @klass        = klass
      @singular     = _singularize(@name)
      @plural       = ActiveSupport::Inflector.pluralize(@singular, locale)
      @uncountable  = @plural == @singular
      @element      = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(@name))
      @human        = ActiveSupport::Inflector.humanize(@element)
      @collection   = ActiveSupport::Inflector.tableize(@name)
      @param_key    = (namespace ? _singularize(@unnamespaced) : @singular)
      @i18n_key     = @name.underscore.to_sym

      @route_key          = (namespace ? ActiveSupport::Inflector.pluralize(@param_key, locale) : @plural.dup)
      @singular_route_key = ActiveSupport::Inflector.singularize(@route_key, locale)
      @route_key << "_index" if @uncountable
    end

    # Transform the model name into a more human format, using I18n. By default,
    # it will underscore then humanize the class name.
    #
    #   class BlogPost
    #     extend ActiveModel::Naming
    #   end
    #
    #   BlogPost.model_name.human # => "Blog post"
    #
    # Specify +options+ with additional translating options.
    def human(options = {})
      return @human if i18n_keys.empty? || i18n_scope.empty?

      key, *defaults = i18n_keys
      defaults << options[:default] if options[:default]
      defaults << MISSING_TRANSLATION

      translation = I18n.translate(key, scope: i18n_scope, count: 1, **options, default: defaults)
      translation = @human if translation == MISSING_TRANSLATION
      translation
    end

    def uncountable?
      @uncountable
    end

    private
      MISSING_TRANSLATION = Object.new # :nodoc:

      def _singularize(string)
        ActiveSupport::Inflector.underscore(string).tr("/", "_")
      end

      def i18n_keys
        @i18n_keys ||= if @klass.respond_to?(:lookup_ancestors)
          @klass.lookup_ancestors.map { |klass| klass.model_name.i18n_key }
        else
          []
        end
      end

      def i18n_scope
        @i18n_scope ||= @klass.respond_to?(:i18n_scope) ? [@klass.i18n_scope, :models] : []
      end
  end

  # == Active \Model \Naming
  #
  # Creates a +model_name+ method on your object.
  #
  # To implement, just extend ActiveModel::Naming in your object:
  #
  #   class BookCover
  #     extend ActiveModel::Naming
  #   end
  #
  #   BookCover.model_name.name   # => "BookCover"
  #   BookCover.model_name.human  # => "Book cover"
  #
  #   BookCover.model_name.i18n_key              # => :book_cover
  #   BookModule::BookCover.model_name.i18n_key  # => :"book_module/book_cover"
  #
  # Providing the functionality that ActiveModel::Naming provides in your object
  # is required to pass the \Active \Model Lint test. So either extending the
  # provided method below, or rolling your own is required.
  module Naming
    def self.extended(base) # :nodoc:
      base.silence_redefinition_of_method :model_name
      base.delegate :model_name, to: :class
    end

    # Returns an ActiveModel::Name object for module. It can be
    # used to retrieve all kinds of naming-related information
    # (See ActiveModel::Name for more information).
    #
    #   class Person
    #     extend ActiveModel::Naming
    #   end
    #
    #   Person.model_name.name     # => "Person"
    #   Person.model_name.class    # => ActiveModel::Name
    #   Person.model_name.singular # => "person"
    #   Person.model_name.plural   # => "people"
    def model_name
      @_model_name ||= begin
        namespace = module_parents.detect do |n|
          n.respond_to?(:use_relative_model_naming?) && n.use_relative_model_naming?
        end
        ActiveModel::Name.new(self, namespace)
      end
    end

    # Returns the plural class name of a record or class.
    #
    #   ActiveModel::Naming.plural(post)             # => "posts"
    #   ActiveModel::Naming.plural(Highrise::Person) # => "highrise_people"
    def self.plural(record_or_class)
      model_name_from_record_or_class(record_or_class).plural
    end

    # Returns the singular class name of a record or class.
    #
    #   ActiveModel::Naming.singular(post)             # => "post"
    #   ActiveModel::Naming.singular(Highrise::Person) # => "highrise_person"
    def self.singular(record_or_class)
      model_name_from_record_or_class(record_or_class).singular
    end

    # Identifies whether the class name of a record or class is uncountable.
    #
    #   ActiveModel::Naming.uncountable?(Sheep) # => true
    #   ActiveModel::Naming.uncountable?(Post)  # => false
    def self.uncountable?(record_or_class)
      model_name_from_record_or_class(record_or_class).uncountable?
    end

    # Returns string to use while generating route names. It differs for
    # namespaced models regarding whether it's inside isolated engine.
    #
    #   # For isolated engine:
    #   ActiveModel::Naming.singular_route_key(Blog::Post) # => "post"
    #
    #   # For shared engine:
    #   ActiveModel::Naming.singular_route_key(Blog::Post) # => "blog_post"
    def self.singular_route_key(record_or_class)
      model_name_from_record_or_class(record_or_class).singular_route_key
    end

    # Returns string to use while generating route names. It differs for
    # namespaced models regarding whether it's inside isolated engine.
    #
    #   # For isolated engine:
    #   ActiveModel::Naming.route_key(Blog::Post) # => "posts"
    #
    #   # For shared engine:
    #   ActiveModel::Naming.route_key(Blog::Post) # => "blog_posts"
    #
    # The route key also considers if the noun is uncountable and, in
    # such cases, automatically appends _index.
    def self.route_key(record_or_class)
      model_name_from_record_or_class(record_or_class).route_key
    end

    # Returns string to use for params names. It differs for
    # namespaced models regarding whether it's inside isolated engine.
    #
    #   # For isolated engine:
    #   ActiveModel::Naming.param_key(Blog::Post) # => "post"
    #
    #   # For shared engine:
    #   ActiveModel::Naming.param_key(Blog::Post) # => "blog_post"
    def self.param_key(record_or_class)
      model_name_from_record_or_class(record_or_class).param_key
    end

    def self.model_name_from_record_or_class(record_or_class) # :nodoc:
      if record_or_class.respond_to?(:to_model)
        record_or_class.to_model.model_name
      else
        record_or_class.model_name
      end
    end
    private_class_method :model_name_from_record_or_class
  end
end
