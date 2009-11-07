module Rails
  module Initializable
    def self.included(base)
      base.extend ClassMethods
    end

    class Initializer
      attr_reader :name, :before, :after, :global, :block

      def initialize(name, context, options, &block)
        @name, @context, @options, @block = name, context, options, block
      end

      def before
        @options[:before]
      end

      def after
        @options[:after]
      end

      def global
        @options[:global]
      end

      alias global? global

      def run(*args)
        @context.instance_exec(*args, &block)
      end

      def bind(context)
        return self if @context
        Initializer.new(@name, context, @options, &block)
      end
    end

    class Collection < Array
      def initialize(initializers = [])
        super()
        initializers.each do |initializer|
          if initializer.before
            index = index_for(initializer.before)
          elsif initializer.after
            index = index_for(initializer.after)
            index += 1 if index
          else
            index = length
          end
          insert(index || -1, initializer)
        end
      end

      def +(other)
        Collection.new(to_a + other.to_a)
      end

      def index_for(name)
        initializer = find { |i| i.name == name }
        initializer && index(initializer)
      end
    end

    def run_initializers(*args)
      return if @ran
      initializers.each do |initializer|
        initializer.run(*args)
      end
      @ran = true
    end

    def initializers
      @initializers ||= begin
        initializers = self.class.initializers_for(:instance)
        Collection.new(initializers.map { |i| i.bind(self) })
      end
    end

    module ClassMethods
      def initializers
        @initializers ||= []
      end

      def initializers_for(scope = :global)
        initializers = Collection.new
        ancestors.reverse_each do |klass|
          next unless klass.respond_to?(:initializers)
          initializers = initializers + klass.initializers.select { |i|
            (scope == :global) == !!i.global?
          }
        end
        initializers
      end

      def initializer(name, opts = {}, &blk)
        @initializers ||= []
        @initializers << Initializer.new(name, nil, opts, &blk)
      end

      def run_initializers(*args)
        return if @ran
        initializers_for(:global).each do |initializer|
          instance_exec(*args, &initializer.block)
        end
        @ran = true
      end
    end
  end

  include Initializable

  # Check for valid Ruby version (1.8.2 or 1.8.4 or higher). This is done in an
  # external file, so we can use it from the `rails` program as well without duplication.
  initializer :check_ruby_version, :global => true do
    require 'rails/ruby_version_check'
  end

  # For Ruby 1.8, this initialization sets $KCODE to 'u' to enable the
  # multibyte safe operations. Plugin authors supporting other encodings
  # should override this behaviour and set the relevant +default_charset+
  # on ActionController::Base.
  #
  # For Ruby 1.9, UTF-8 is the default internal and external encoding.
  initializer :initialize_encoding, :global => true do
    if RUBY_VERSION < '1.9'
      $KCODE='u'
    else
      Encoding.default_external = Encoding::UTF_8
    end
  end
end