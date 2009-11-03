module Rails
  module Initializable
    def self.included(klass)
      klass.instance_eval do
        extend Rails::Initializable
        extend Rails::Initializable::ClassMethodsWhenIncluded
        include Rails::Initializable::InstanceMethodsWhenIncluded
      end
    end

    def self.extended(klass)
      klass.extend Initializer
    end

    class Collection < Array
      def initialize(klasses)
        klasses.each do |klass|
          (klass.added_initializers || []).each do |initializer|
            index = if initializer.before
              index_for(initializer.before)
            elsif initializer.after
              index_for(initializer.after) + 1
            else
              length
            end

            insert(index, initializer)
          end
        end
      end

      def index_for(name)
        inst = find {|i| i.name == name }
        inst && index(inst)
      end

    end

    attr_reader :added_initializers

    # When you include Rails::Initializable, this method will be on instances
    # of the class included into. When you extend it, it will be on the
    # class or module itself.
    #
    # The #initializers method is set up to return the right list of
    # initializers for the context in question.
    def run_initializers
      return if @_initialized

      initializers.each {|initializer| instance_eval(&initializer.block) }

      @_initialized = true
    end

    module Initializer
      Initializer = Struct.new(:name, :before, :after, :block, :global)

      def all_initializers
        klasses = ancestors.select {|klass| klass.is_a?(Initializable) }.reverse
        initializers = Collection.new(klasses)
      end

      alias initializers all_initializers

      def initializer(name, options = {}, &block)
        @added_initializers ||= []
        @added_initializers <<
          Initializer.new(name, options[:before], options[:after], block, options[:global])
      end
    end

    module ClassMethodsWhenIncluded
      def initializers
        all_initializers.select {|i| i.global == true }
      end

    end

    module InstanceMethodsWhenIncluded
      def initializers
        self.class.all_initializers.reject {|i| i.global == true }
      end
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