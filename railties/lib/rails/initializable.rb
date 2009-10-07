module Rails
  module Initializable

    # A collection of initializers
    class Collection < ActiveSupport::OrderedHash
      # def initialize_copy(other)
      #   super
      #   each do |key, value|
      #     self[key] = value.dup
      #   end
      # end

      def run
        each do |key, initializer|
          initializer.run
        end
        self
      end
    end

    class Initializer
      attr_reader :name, :options, :block

      def initialize(name, options = {}, &block)
        @name, @options, @block = name, options, block
      end

      def run
        return if @already_ran
        @block.call
        @already_ran = true
      end
    end

    def initializer(name, options = {}, &block)
      initializers[name] = Initializer.new(name, options, &block)
    end

    def initializers
      @initializers ||= Collection.new
    end

    def initializers=(initializers)
      @initializers = initializers
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