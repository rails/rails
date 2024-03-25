# frozen_string_literal: true

module ActiveModel
  module Type
    # = Active Model \Model \Type
    #
    # Attribute type for ActiveModel::Model representation.
    #
    #   class Article
    #     include ActiveModel::Attributes
    #
    #     attribute :author, class_name: "Person"
    #     attribute :comments, class_name: "Comment", array: true
    #   end
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :name, :string
    #   end
    #
    #   class Comment
    #     include ActiveModel::Attributes
    #
    #     attribute :body, :string
    #   end
    #
    # Values are cast first using their +attributes+ method, if they've defined
    # one, then falling back to their +to_h+. +nil+ values are cast to +nil+.
    # If an instance of the class defined by the +:class+ option
    # is passed, the attribute will not be cast and will reference the instance
    # directly. If an +attributes+ method is not defined or raises an error, the
    # value will be cast to +nil+.
    #
    #   article = Article.new
    #
    #   article.author = { name: "Arthur" }
    #   article.author.name # => "Arthur"
    #
    #   article.author = nil
    #   article.author # => nil
    #
    #   person = Person.new name: "Arthur"
    #   article.author = person
    #   article.author.name #=> "Arthur"
    #   article.author.eql?(person) #=> true
    #
    #   article.author = :not_a_model
    #   article.author # => nil (because Symbol does not define #attributes)
    #
    # When the attribute is defined with a true +:array+ option, the model will
    # assign Arrays of instances or attributes:
    #
    #   article = Article.new
    #
    #   article.comments = [{ body: "Hello" }, { body: "Goodbye" }]
    #   article.comments.map(&:body) # => ["Hello", "Goodbye"]
    #
    #   hello = Comment.new body: "Hello"
    #   goodbye = Comment.new body: "Goodbye"
    #
    #   article.comments.map(&:body) # => ["Hello", "Goodbye"]
    #   article.comments.first.eql?(hello) #=> true
    #   article.comments.last.eql?(goodbye) #=> true
    #
    #   article.comments = []
    #   article.comments #=> []
    #
    #   article.comments = nil
    #   article.comments #=> []
    class Model < Value
      def initialize(array: false, **options)
        model_class = options.delete(:class) || options.delete(:class_name).try(:safe_constantize)
        raise ArgumentError.new("pass either a Class as the :class option or a String as the :class_name option") unless model_class.is_a?(Class)

        @model_class = model_class
        @array = array
        super(**options)
      end

      private
        attr_reader :array, :model_class

        def cast_value(value)
          if array
            Array(value).map { cast_to_model(_1) }
          else
            cast_to_model(value)
          end
        end

        def cast_to_model(value)
          case value
          when NilClass
            nil
          when model_class
            value
          when Hash
            model_class.new(value)
          else
            model_class.new(value.try(:attributes) || value.try(:to_h))
          end
        end
    end
  end
end
