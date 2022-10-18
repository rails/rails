# frozen_string_literal: true

require "cases/helper"
require "action_controller"
require "models/marc"
require "models/marc/record"

class SomeCollection
  include Enumerable
  include ActiveModel::Embedding::Collecting
end

class SomeType < ActiveModel::Type::Value
  def cast(value)
    value.cast_type = self.class
    super
  end
end

ActiveModel::Type.register(:some_type, SomeType)

class SomeOtherType < ActiveModel::Type::Value
  attr_reader :context

  def initialize(context:)
    @context = context
  end

  def cast(value)
    value.cast_type = self.class
    value.context   = context
    super
  end
end

class Thing
  attr_accessor :cast_type
  attr_accessor :context
end

class SomeModel
  include ActiveModel::Embedding::Document

  embeds_many :things, collection: "SomeCollection", cast_type: :some_type
  embeds_many :other_things, cast_type: SomeOtherType.new(context: self)
end

class EmbeddingTest < ActiveRecord::TestCase
  fixtures "marc/records"

  setup do
    @record     = marc_records(:hamlet)
    @some_model = SomeModel.new things: Array.new(3) { Thing.new }, other_things: Array.new(3) { Thing.new }
  end

  test "should handle mass assignment correctly" do
    field = ::MARC::Record::Field.new tag: "200"
    subfields_attributes = [{ code: "a", value: "Getting Real" }, { code: "3", value: "..." }]

    field.subfields = subfields_attributes
    assert_equal MARC::Record::Field::Subfield, field.subfields.document_class

    params    = ::ActionController::Parameters.new(subfields_attributes: { "0" => { value: "Rework" } })
    permitted = params.permit(subfields_attributes: [:id, :value])

    field.subfields_attributes = permitted[:subfields_attributes]
    assert_equal "Rework", field.subfields.first.value

    assert field.subfields.save
    assert field.subfields.all?(&:id)

    id           = field.subfields.first.id
    random_index = rand 100
    params       = ::ActionController::Parameters.new(subfields_attributes: { "#{random_index}" => { id: id, value: "ShapeUp" } })
    permitted    = params.permit(subfields_attributes: [:id, :value])

    field.subfields_attributes = permitted[:subfields_attributes]
    assert_equal "ShapeUp", field.subfields.first.value

    params = ::ActionController::Parameters.new(subfields_attributes: { "#{random_index}" => { id: id, value: "..." } })

    assert_raises { field.subfields_attributes = params }
  end

  test "should autosave embedded documents" do
    @record["245"]["a"].value = "Romeo and Juliet"

    assert @record.save

    @record.reload

    assert_equal "Romeo and Juliet", @record["245"]["a"].value

    assert @record["245"]["a"].persisted?
  end

  test "should perform validations" do
    assert @record.valid?

    last_field = @record.fields.to_a.last

    last_field.subfields.first.code = ""

    assert_not @record.valid?
    assert_not @record.save

    last_field.subfields.first.code = "a"

    assert @record.valid?
    assert @record.save
  end

  test "should track changes" do
    assert_not @record.changed?

    @record["245"]["a"].value = "Romeo and Juliet"

    assert @record.changed?
  end

  test "should handle custom collections" do
    assert_equal SomeCollection, @some_model.things.class
    assert_equal Thing, @some_model.things.document_class
  end

  test "should handle custom types" do
    assert_equal SomeType, @some_model.things.first.cast_type
    assert_equal SomeOtherType, @some_model.other_things.first.cast_type
    assert_equal SomeModel, @some_model.other_things.first.context
  end

  test "should handle values that are already type casted" do
    fields = @record.fields

    @record.fields = nil
    @record.fields = fields

    assert @record.fields
  end
end
