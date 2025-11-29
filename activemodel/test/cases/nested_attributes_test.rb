# frozen_string_literal: true

require "cases/helper"

NestedStruct = Struct.new(:name)

class NestedModel
  class Type < ActiveModel::Type::Value
    private
      def cast_value(value)
        case value
        when NestedModel then value
        else NestedModel.new(value)
        end
      end
  end

  class ArrayType < Type
    private
      def cast_value(value)
        case value
        when Array then value.map { |attributes| cast(attributes) }
        else super
        end
      end
  end

  include ActiveModel::Model

  attr_accessor :name

  def attributes
    { "name" => name }
  end
end

class NestedRecord < NestedModel
  def mark_for_destruction
    @marked_for_destruction = true
  end

  def marked_for_destruction?
    @marked_for_destruction
  end

  def _destroy
    marked_for_destruction?
  end
end

module ActiveModel
  class NestedAttributesTest < ActiveModel::TestCase
    test "accepts attributes for one-to-one Active Model" do
      model = model_class do
        attr_accessor :has_one_model

        accepts_nested_attributes_for :has_one_model, class_name: "NestedModel"
      end

      instance = model.new has_one_model_attributes: { name: "Has One" }

      assert_kind_of NestedModel, instance.has_one_model
      assert_equal "Has One", instance.has_one_model.name
      assert_not_predicate instance.has_one_model, :persisted?
    end

    test "accepts attributes for one-to-one Active Model by inferring its class_name: through inflection" do
      model = model_class do
        attr_accessor :nested_model

        accepts_nested_attributes_for :nested_model
      end

      instance = model.new nested_model_attributes: { name: "Has One" }

      assert_kind_of NestedModel, instance.nested_model
      assert_equal "Has One", instance.nested_model.name
      assert_not_predicate instance.nested_model, :persisted?
    end

    test "accepts attributes for one-to-one Active Model by inferring its class_name: through Attribute definition" do
      model = model_class do
        include ActiveModel::Attributes

        attribute :nested_model, NestedModel::Type.new

        accepts_nested_attributes_for :nested_model
      end

      instance = model.new nested_model_attributes: { name: "Has One" }

      assert_kind_of NestedModel, instance.nested_model
      assert_equal "Has One", instance.nested_model.name
      assert_not_predicate instance.nested_model, :persisted?
    end

    test "omits unassignable attributes for one-to-one Active Model inferred through Attribute definition" do
      model = model_class do
        include ActiveModel::Attributes

        attribute :nested_model, NestedModel::Type.new

        accepts_nested_attributes_for :nested_model
      end

      instance = model.new nested_model_attributes: { _destroy: true }

      assert_kind_of NestedModel, instance.nested_model
      assert_not_includes instance.nested_model.attributes.keys, "_destroy"
    end

    test "overrides one-to-one inference when array: false" do
      model = model_class do
        attr_accessor :deer

        accepts_nested_attributes_for :deer, array: false, class_name: "NestedModel"
      end

      instance = model.new deer_attributes: { name: "Has One" }

      assert_kind_of NestedModel, instance.deer
      assert_equal "Has One", instance.deer.name
      assert_not_predicate instance.deer, :persisted?
    end

    test "builds an instance of a one-to-one Active Model from attributes" do
      model = model_class do
        attr_accessor :has_one_model

        accepts_nested_attributes_for :has_one_model

        def build_has_one_model(attributes)
          NestedModel.new(attributes)
        end
      end

      instance = model.new has_one_model_attributes: { name: "Has One" }

      assert_kind_of NestedModel, instance.has_one_model
      assert_equal "Has One", instance.has_one_model.name
      assert_not_predicate instance.has_one_model, :persisted?
    end

    test "gives precedent to the build method over the class_name: option for one-to-one Active Model instances" do
      model = model_class do
        attr_accessor :has_one_model

        accepts_nested_attributes_for :has_one_model, class_name: "NestedModel"

        def build_has_one_model(attributes)
          NestedStruct.new(attributes[:name])
        end
      end

      instance = model.new has_one_model_attributes: { name: "Has One" }

      assert_kind_of NestedStruct, instance.has_one_model
      assert_equal "Has One", instance.has_one_model.name
    end

    test "builds an instance using the reject_if: option" do
      model = model_class do
        attr_accessor :has_one_model

        accepts_nested_attributes_for :has_one_model, class_name: "NestedModel",
          reject_if: -> (attributes) { attributes[:name] == "reject" }
      end

      instance = model.new has_one_model_attributes: { name: "reject" }

      assert_nil instance.has_one_model
    end

    test "accepts_attributes_for one-to-many of Active Models" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models, class_name: "NestedModel"
      end

      instance = model.new has_many_models_attributes: { 0 => { name: "Has Many" } }

      instance.has_many_models.each { |model| assert_kind_of NestedModel, model }
      assert_not instance.has_many_models.any?(&:persisted?)
      assert_equal ["Has Many"], instance.has_many_models.map(&:name)
    end

    test "accepts_attributes_for one-to-many of Active Models inferring their class_name: through inflection" do
      model = model_class do
        attr_accessor :nested_models

        accepts_nested_attributes_for :nested_models
      end

      instance = model.new nested_models_attributes: { 0 => { name: "Has Many" } }

      instance.nested_models.each { |model| assert_kind_of NestedModel, model }
      assert_not instance.nested_models.any?(&:persisted?)
      assert_equal ["Has Many"], instance.nested_models.map(&:name)
    end

    test "accepts attributes for one-to-many Active Model by inferring its class_name: through Attribute definition" do
      model = model_class do
        include ActiveModel::Attributes

        attribute :nested_models, NestedModel::ArrayType.new

        accepts_nested_attributes_for :nested_models
      end

      instance = model.new nested_models_attributes: { 0 => { name: "Has Many" } }

      instance.nested_models.each { |model| assert_kind_of NestedModel, model }
      assert_not instance.nested_models.any?(&:persisted?)
      assert_equal ["Has Many"], instance.nested_models.map(&:name)
    end

    test "ignores unassignable attributes for one-to-many inferred through Attribute definition" do
      model = model_class do
        include ActiveModel::Attributes

        attribute :nested_models, NestedModel::ArrayType.new

        accepts_nested_attributes_for :nested_models
      end

      instance = model.new nested_models_attributes: { 0 => { name: "Has Many", _destroy: false } }

      instance.nested_models.each { |model| assert_kind_of NestedModel, model }
      assert_not instance.nested_models.any?(&:persisted?)
      assert_equal ["Has Many"], instance.nested_models.map(&:name)
    end

    test "builds one-to-many Active Model from attributes" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models

        def build_has_many_model(attributes)
          NestedModel.new(attributes)
        end
      end

      instance = model.new has_many_models_attributes: {
        0 => { name: "First" },
        1 => { name: "Last" },
      }

      instance.has_many_models.each { |model| assert_kind_of NestedModel, model }
      instance.has_many_models.each { |model| assert_not_predicate model, :persisted? }
      assert_equal ["First", "Last"], instance.has_many_models.map(&:name)
    end

    test "overrides one-to-many inference when array: true" do
      model = model_class do
        attr_accessor :deer

        accepts_nested_attributes_for :deer, array: true, class_name: "NestedModel"
      end

      instance = model.new deer_attributes: {
        0 => { name: "First" },
        1 => { name: "Last" },
      }

      instance.deer.each { |model| assert_kind_of NestedModel, model }
      instance.deer.each { |model| assert_not_predicate model, :persisted? }
      assert_equal ["First", "Last"], instance.deer.map(&:name)
    end

    test "gives precedent to the build method for a one-to-many attributes" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models, class_name: "NestedModel"

        def build_has_many_model(attributes)
          NestedStruct.new(attributes[:name])
        end
      end

      instance = model.new has_many_models_attributes: { 0 => { name: "Has Many" } }

      instance.has_many_models.each { |model| assert_kind_of NestedStruct, model }
      assert_equal ["Has Many"], instance.has_many_models.map(&:name)
    end

    test "builds a one-to-many instances excluding nils" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models

        def build_has_many_model(attributes)
          NestedModel.new(name: "include") if attributes[:include]
        end
      end

      instance = model.new has_many_models_attributes: {
        0 => { include: true },
        1 => { include: false },
      }

      instance.has_many_models.each { |model| assert_kind_of NestedModel, model }
      instance.has_many_models.each { |model| assert_not_predicate model, :persisted? }
      assert_equal ["include"], instance.has_many_models.map(&:name)
    end

    test "builds a one-to-many instances using the reject_if: option" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models, class_name: "NestedModel",
          reject_if: -> (attributes) { attributes[:name] == "reject" }
      end

      instance = model.new has_many_models_attributes: {
        0 => { name: "reject" },
        1 => { name: "include" },
      }

      instance.has_many_models.each { |model| assert_kind_of NestedModel, model }
      instance.has_many_models.each { |model| assert_not_predicate model, :persisted? }
      assert_equal ["include"], instance.has_many_models.map(&:name)
    end

    test "raises TooManyModels if one-to-many is larger than configured limit:" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models, class_name: "NestedModel",
          limit: 1
      end

      assert_raises ActiveModel::NestedAttributes::TooManyModels do
        model.new has_many_models_attributes: {
          0 => { name: "ignored" },
          1 => { name: "ignored" },
        }
      end
    end

    test "raises TooManyModels if one-to-many is larger than Symbol limit:" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models, class_name: "NestedModel",
          limit: :models_limit

        def models_limit
          1
        end
      end

      assert_raises ActiveModel::NestedAttributes::TooManyModels do
        model.new has_many_models_attributes: {
          0 => { name: "ignored" },
          1 => { name: "ignored" },
        }
      end
    end

    test "raises TooManyModels if one-to-many is larger than Proc limit:" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models, class_name: "NestedModel",
          limit: -> { 1 }
      end

      assert_raises ActiveModel::NestedAttributes::TooManyModels do
        model.new has_many_models_attributes: {
          0 => { name: "ignored" },
          1 => { name: "ignored" },
        }
      end
    end

    test "base has empty nested_attributes_options" do
      model = model_class

      assert_equal({}, model.nested_attributes_options)
    end

    test "replaces nested_attributes_options[:reject_if] with a proc" do
      model = model_class do
        attr_accessor :has_one_model

        accepts_nested_attributes_for :has_one_model, class_name: "NestedModel", reject_if: :all_blank
      end

      assert_equal ActiveModel::NestedAttributes::ClassMethods::REJECT_ALL_BLANK_PROC,
        model.nested_attributes_options.dig(:has_one_model, :reject_if)
    end

    test "does not build a new model if reject_if: :all_blank returns false" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models, class_name: "NestedModel", reject_if: :all_blank
      end

      instance = model.new has_many_models_attributes: { 0 => { name: "" } }

      assert_empty instance.has_many_models
    end

    test "builds a new model if reject_if: :all_blank is truthy" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models, class_name: "NestedModel", reject_if: :all_blank
      end

      instance = model.new has_many_models_attributes: { 0 => { name: "valid" } }

      assert_equal ["valid"], instance.has_many_models.map(&:name)
    end

    test "raises an ArgumentError for one-to-many attributes that are not Hash or Array" do
      model = model_class do
        attr_accessor :has_many_models

        accepts_nested_attributes_for :has_many_models, class_name: "NestedModel"
      end

      assert_raises ArgumentError, match: "Hash or Array expected for attribute `has_many_models`, got #{1.class.name} (#{1.inspect})" do
        model.new has_many_models_attributes: 1
      end
    end

    test "raises an ArgumentError for undeclared attributes" do
      assert_raises ArgumentError, match: "No attribute found for name `undeclared`. Has it been defined yet?" do
        model_class.accepts_nested_attributes_for :undeclared
      end
    end

    test "raises an ArgumentError for when the class_name: option is neither a String nor a Class" do
      model = model_class do
        attr_accessor :unknown

        accepts_nested_attributes_for :unknown, class_name: :invalid
      end

      assert_raises ArgumentError, match: "Cannot build attribute `unknown` with class_name: invalid" do
        model.new unknown_attributes: { ignored: true }
      end
    end

    test "raises an ArgumentError for when the class_name: option is missing" do
      model = model_class do
        attr_accessor :unknown

        accepts_nested_attributes_for :unknown
      end

      assert_raises ArgumentError, match: "Cannot build attribute `unknown`. Specify a class_name: option or define `#build_unknown`" do
        model.new unknown_attributes: { ignored: true }
      end
    end

    test "raises an UnknownAttributeError for undeclared attributes on the nested model" do
      model = model_class do
        attr_accessor :has_one_model

        accepts_nested_attributes_for :has_one_model, class_name: "NestedModel"
      end

      assert_raises ActiveModel::UnknownAttributeError, match: "unknown attribute 'not_declared' for NestedModel." do
        model.new(has_one_model_attributes: { not_declared: true })
      end
    end

    test "defaults to allow_destroy: false" do
      model = model_class do
        attr_accessor :has_one_model

        accepts_nested_attributes_for :has_one_model, class_name: "NestedModel"
      end

      attributes = { "name" => "Has One" }
      nested_model = NestedModel.new(attributes)
      instance = model.new(has_one_model: nested_model)

      instance.assign_attributes(has_one_model_attributes: attributes.merge("_destroy" => true))

      assert_equal attributes, instance.has_one_model.attributes
    end

    test "supports allow_destroy: true with a model" do
      model = model_class do
        attr_accessor :has_one_model

        accepts_nested_attributes_for :has_one_model, class_name: "NestedModel", allow_destroy: true
      end
      instance = model.new(has_one_model: NestedModel.new(name: "Has One"))

      instance.assign_attributes(has_one_model_attributes: { "_destroy" => true })

      assert_nil instance.has_one_model
    end

    test "supports allow_destroy: true with a record" do
      model = model_class do
        attr_accessor :has_one_record

        accepts_nested_attributes_for :has_one_record, class_name: "NestedRecord", allow_destroy: true
      end
      instance = model.new(has_one_record: NestedRecord.new(name: "Has One"))

      instance.assign_attributes(has_one_record_attributes: { "_destroy" => true })

      assert_predicate instance.has_one_record, :marked_for_destruction?
      assert_predicate instance.has_one_record, :_destroy
    end

    def model_class(&block)
      Class.new do
        include ActiveModel::Model
        include ActiveModel::NestedAttributes

        class_eval(&block) unless block.nil?
      end
    end
  end
end
