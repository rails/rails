# frozen_string_literal: true

require "cases/helper"
require "models/post"

module ActiveModel
  module Type
    class ModelTest < ActiveModel::TestCase
      setup do
        @type = Type::Model.new(class_name: "Post")
      end

      test "#cast returns a new model instance from the given hash" do
        model = @type.cast(title: "Greeting", body: "Hello!")

        assert_equal "Greeting", model.title
        assert_equal "Hello!", model.body
      end

      test "#cast returns a new model instance from the given model instance" do
        model = Post.new(title: "Greeting", body: "Hello!")

        new_model = @type.cast(model)

        assert_equal "Greeting", new_model.title
        assert_equal "Hello!", new_model.body

        assert_not_same model, new_model
      end

      test "#valid_value? returns true if the value is an object of the same class as the type" do
        model = Post.new(title: "Greeting", body: "Hello!")

        assert @type.valid_value?(model)
      end

      test "#valid_value? returns true if the value is a hash that contains only supported keys" do
        model_hash = { title: "Greeting", body: "Hello!" }

        assert @type.valid_value?(model_hash)
      end

      test "#valid_value? returns true if the value is a hash that contains only required keys" do
        model_hash = { title: "Greeting" }

        assert @type.valid_value?(model_hash)
      end

      test "#valid_value? returns false if value is a hash but with not-supported keys" do
        model_hash = { title: "Greeting", body: "Hello!", what_am_i: "I'm not supposed to be here" }

        assert_not @type.valid_value?(model_hash)
      end

      test "valid_value? returns false if value is neither a hash or an object of the type class" do
        assert_not @type.valid_value?("Just a string")
      end

      test "#serialize serializes object as values_for_database" do
        model = Post.new(title: "Greeting", body: "Hello!")
        expected = "Hello! Post; serialized"
        serializer = Minitest::Mock.new
        type = Type::Model.new(class_name: "Post", serializer: serializer)

        serializer.expect(:encode, expected, [model.attributes])

        serialized = type.serialize(model)
        assert_equal(expected, serialized)
      end

      test "#deserialize deserializes attributes set and instantiates an object of the type class" do
        serialized = "Hello! Post; serialized"
        attributes_set = { "title" => "Greeting", "body" => "Hello!"  }
        serializer = Minitest::Mock.new
        type = Type::Model.new(class_name: "Post", serializer: serializer)

        serializer.expect(:decode, attributes_set, [serialized])
        model = type.deserialize(serialized)

        assert_equal "Greeting", model.title
        assert_equal "Hello!", model.body
      end

      test "#serializable? returns true if value of the same class as the type" do
        assert @type.serializable?(Post.new)
      end

      test "#serializable? returns false if value is not of the same class as the type" do
        assert_not @type.serializable?("i'm not a post")
      end

      test "#changed_in_place? returns false if object attributes are the same" do
        serialized_old_post = "#Post"
        old_post, new_post = 2.times.map { Post.new(title: "Greeting") }
        @type.stub(:deserialize, old_post) do
          assert_not @type.changed_in_place?(serialized_old_post, new_post)
        end
      end

      test "#changed_in_place? returns true if object attributes are not the same" do
        serialized_old_post = "#Post"
        old_post = Post.new(title: "Greeting")
        new_post = Post.new(title: "About me")
        @type.stub(:deserialize, old_post) do
          assert @type.changed_in_place?(serialized_old_post, new_post)
        end
      end
    end
  end
end
