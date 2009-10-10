module Rails
  module Initializable

    # A collection of initializers
    class Collection
      def initialize(context)
        @context = context
        @keys    = []
        @values  = {}
        @ran     = false
      end

      def run
        return self if @ran
        each do |key, initializer|
          @context.class_eval(&initializer.block)
        end
        @ran = true
        self
      end

      def [](key)
        keys, values = merge_with_parent
        values[key.to_sym]
      end

      def []=(key, value)
        key = key.to_sym
        @keys |= [key]
        @values[key] = value
      end

      def each
        keys, values = merge_with_parent
        keys.each { |k| yield k, values[k] }
        self
      end

    protected

      attr_reader :keys, :values

    private

      def merge_with_parent
        keys, values = [], {}

        if @context.is_a?(Class) && @context.superclass.is_a?(Initializable)
          parent = @context.superclass.initializers
          keys, values = parent.keys, parent.values
        end

        values = values.merge(@values)
        return keys | @keys, values
      end

    end

    class Initializer
      attr_reader :name, :options, :block

      def initialize(name, options = {}, &block)
        @name, @options, @block = name, options, block
      end
    end

    def initializer(name, options = {}, &block)
      @initializers ||= Collection.new(self)
      @initializers[name] = Initializer.new(name, options, &block)
    end

    def initializers
      @initializers ||= Collection.new(self)
    end

  end

  extend Initializable

  # Check for valid Ruby version (1.8.2 or 1.8.4 or higher). This is done in an
  # external file, so we can use it from the `rails` program as well without duplication.
  initializer :check_ruby_version do
    require 'rails/ruby_version_check'
  end

  # For Ruby 1.8, this initialization sets $KCODE to 'u' to enable the
  # multibyte safe operations. Plugin authors supporting other encodings
  # should override this behaviour and set the relevant +default_charset+
  # on ActionController::Base.
  #
  # For Ruby 1.9, UTF-8 is the default internal and external encoding.
  initializer :initialize_encoding do
    if RUBY_VERSION < '1.9'
      $KCODE='u'
    else
      Encoding.default_external = Encoding::UTF_8
    end
  end
end