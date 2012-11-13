module ActiveRecord
  module DynamicMatchers #:nodoc:
    # This code in this file seems to have a lot of indirection, but the indirection
    # is there to provide extension points for the activerecord-deprecated_finders
    # gem. When we stop supporting activerecord-deprecated_finders (from Rails 5),
    # then we can remove the indirection.

    def respond_to?(name, include_private = false)
      match = Method.match(self, name)
      match && match.valid? || super
    end

    private

    def method_missing(name, *arguments, &block)
      match = Method.match(self, name)

      if match && match.valid?
        match.define
        send(name, *arguments, &block)
      else
        super
      end
    end

    class Method
      @matchers = []

      class << self
        attr_reader :matchers

        def match(model, name)
          klass = matchers.find { |k| name =~ k.pattern }
          klass.new(model, name) if klass
        end

        def pattern
          /^#{prefix}_([_a-zA-Z]\w*)#{suffix}$/
        end

        def prefix
          raise NotImplementedError
        end

        def suffix
          ''
        end
      end

      attr_reader :model, :name, :attribute_names

      def initialize(model, name)
        @model           = model
        @name            = name.to_s
        @attribute_names = @name.match(self.class.pattern)[1].split('_and_')
        @attribute_names.map! { |n| @model.attribute_aliases[n] || n }
      end

      def valid?
        attribute_names.all? { |name| model.columns_hash[name] || model.reflect_on_aggregation(name.to_sym) }
      end

      def define
        model.class_eval <<-CODE, __FILE__, __LINE__ + 1
          def self.#{name}(#{signature})
            #{body}
          end
        CODE
      end

      def body
        raise NotImplementedError
      end
    end

    module Finder
      # Extended in activerecord-deprecated_finders
      def body
        result
      end

      # Extended in activerecord-deprecated_finders
      def result
        "#{finder}(#{attributes_hash})"
      end

      # Extended in activerecord-deprecated_finders
      def signature
        attribute_names.join(', ')
      end

      def attributes_hash
        "{" + attribute_names.map { |name| ":#{name} => #{name}" }.join(',') + "}"
      end

      def finder
        raise NotImplementedError
      end
    end

    class FindBy < Method
      Method.matchers << self
      include Finder

      def self.prefix
        "find_by"
      end

      def finder
        "find_by"
      end
    end

    class FindByBang < Method
      Method.matchers << self
      include Finder

      def self.prefix
        "find_by"
      end

      def self.suffix
        "!"
      end

      def finder
        "find_by!"
      end
    end
  end
end
