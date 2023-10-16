# frozen_string_literal: true

require "cases/helper"

class PersistenceTest < ActiveModel::TestCase
  class Model
    include ActiveModel::Persistence

    attr_accessor :name, :description

    def initialize(attributes, &block)
      attributes.each { |k, v| send("#{k}=", v) }

      tap { yield self if block_given? }
    end
  end

  test "create many" do
    models = Model.create([ { "name" => "first" }, { "name" => "second" }])
    assert_equal 2, models.size
    assert_equal "first", models.first.name
  end

  test "create through factory with block" do
    model = Model.create("name" => "New Model") do |t|
      t.description = "Description"
    end
    assert_equal("New Model", model.name)
    assert_equal("Description", model.description)
  end

  test "create many through factory with block" do
    model1, model2, *rest = Model.create([ { "name" => "first" }, { "name" => "second" }]) do |t|
      t.description = "Description"
    end
    assert_empty rest
    assert_equal "first", model1.name
    assert_equal "Description", model1.description
    assert_equal "second", model2.name
    assert_equal "Description", model2.description
  end

  test "create! many" do
    models = Model.create!([ { "name" => "first" }, { "name" => "second" }])
    assert_equal 2, models.size
    assert_equal "first", models.first.name
  end

  test "create! through factory with block" do
    model = Model.create!("name" => "New Model") do |t|
      t.description = "Description"
    end
    assert_equal("New Model", model.name)
    assert_equal("Description", model.description)
  end

  test "create! many through factory with block" do
    model1, model2, *rest = Model.create!([ { "name" => "first" }, { "name" => "second" }]) do |t|
      t.description = "Description"
    end
    assert_empty rest
    assert_equal "first", model1.name
    assert_equal "Description", model1.description
    assert_equal "second", model2.name
    assert_equal "Description", model2.description
  end
end
