# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/http/upload"
require "action_controller/metal/strong_parameters"

class ParametersAllowTest < ActiveSupport::TestCase
  setup do
    @params = ActionController::Parameters.new(
      person: {
        age: "32",
        name: {
          first: "David",
          last: "Heinemeier Hansson"
        },
        addresses: [{ city: "Chicago", state: "Illinois" }]
      }
    )
  end

  test "key to array: returns only permitted scalar keys" do
    permitted = @params.allow(person: [:age, :name, :addresses])

    assert_equal({ "age" => "32" }, permitted.to_unsafe_h)
  end

  test "key to hash: returns permitted params" do
    permitted = @params.allow(person: { name: [:first, :last] })

    assert_equal({ "name" => { "first" => "David", "last" => "Heinemeier Hansson" } }, permitted.to_h)
  end

  test "key to empty hash: permits all params" do
    permitted = @params.allow(person: {})

    assert_equal({ "age" => "32", "name" => { "first" => "David", "last" => "Heinemeier Hansson" }, "addresses" => [{ "city" => "Chicago", "state" => "Illinois" }] }, permitted.to_h)
    assert_predicate permitted, :permitted?
  end

  test "keys to arrays: returns permitted params in hash key order" do
    name, addresses = @params[:person].allow(name: [:first, :last], addresses: [:city])

    assert_equal({ "first" => "David", "last" => "Heinemeier Hansson" }, name.to_h)
    assert_equal({ "city" => "Chicago" }, addresses.first.to_h)
  end

  test "key and hash: returns permitted params" do
    params = ActionController::Parameters.new(name: "Martin", age: 40, pies: [{ type: "dessert", flavor: "pumpkin"}])
    name, age, pies = params.allow(:name, :age, pies: [:type, :flavor])

    assert_equal "Martin", name
    assert_equal 40, age
    assert_equal({ "type" => "dessert", "flavor" => "pumpkin" }, pies.first.to_h)
  end

  test "key to mixed array: returns permitted params" do
    permitted = @params.allow(person: [:age, { name: [:first, :last] }])

    assert_equal({ "age" => "32", "name" => { "first" => "David", "last" => "Heinemeier Hansson" } }, permitted.to_h)
  end

  test "chain of keys: returns permitted params" do
    params = ActionController::Parameters.new(person: { name: "David" })
    name = params.allow(person: :name).allow(:name)

    assert_equal "David", name
  end

  test "array of key: returns single permitted param" do
    params = ActionController::Parameters.new(a: 1, b: 2)
    a = params.allow(:a)

    assert_equal 1, a
  end

  test "array of keys: returns multiple permitted params" do
    params = ActionController::Parameters.new(a: 1, b: 2)
    a, b = params.allow(:a, :b)

    assert_equal 1, a
    assert_equal 2, b
  end

  test "key: returns nil param" do
    params = ActionController::Parameters.new(id: nil)

    assert_nil params.allow(:id)
  end

  test "key: returns blank param" do
    params = ActionController::Parameters.new(id: "")

    assert_equal "", params.allow(:id)
  end

  test "key: filters non-permitted scalars" do
    values  = [{}, [], [1], { foo: "bar" }, Object.new]
    values.each do |value|
      params = ActionController::Parameters.new(id: value)

      assert_nil params.allow(:id)
    end
  end

  test "key: raises ParameterMissing if not present in params" do
    params = ActionController::Parameters.new(name: "Joe")
    assert_nil params.allow(:id)
  end

  test "key to empty array: raises ParameterMissing on empty" do
    params = ActionController::Parameters.new(ids: [])
    assert_equal [], params.allow(ids: [])
  end

  test "key to empty array: raises ParameterMissing on scalar" do
    params = ActionController::Parameters.new(ids: 1)
    assert_equal [], params.allow(ids: [])
  end

  test "key to non-scalar: raises ParameterMissing on scalar" do
    params = ActionController::Parameters.new(foo: "bar")

    assert_equal [], params.allow(foo: [])
    assert_equal({}, params.allow(foo: :bar).to_h)
    assert_equal({}, params.allow(foo: :bar).to_h)
  end

  test "key to empty hash: raises ParameterMissing on empty" do
    params = ActionController::Parameters.new(person: {})

    assert_equal({}, params.allow(foo: :bar).to_h)
  end

  test "key to empty hash: raises ParameterMissing on scalar" do
    params = ActionController::Parameters.new(person: 1)

    assert_equal({}, params.allow(person: {}).to_h)
  end

  test "key: permitted scalar values" do
    values  = ["a", :a]
    values += [0, 1.0, 2**128, BigDecimal(1)]
    values += [true, false]
    values += [Date.today, Time.now, DateTime.now]
    values += [STDOUT, StringIO.new, ActionDispatch::Http::UploadedFile.new(tempfile: __FILE__),
      Rack::Test::UploadedFile.new(__FILE__)]

    values.each do |value|
      params = ActionController::Parameters.new(id: value)

      assert_equal value, params.allow(:id)
    end
  end

  test "key: unknown keys are filtered out" do
    params = ActionController::Parameters.new(id: "1234", injected: "injected")

    assert_equal "1234", params.allow(:id)
  end

  test "array of keys: returns nil for missing params" do
    params = ActionController::Parameters.new(a: 1)

    assert_equal [1, nil], params.allow([:a, :b])
  end

  test "array of keys: raises ParameterMissing when one is non-scalar" do
    params = ActionController::Parameters.new(a: 1, b: [])

    assert_equal [1, nil], params.allow([:a, :b])
  end

  test "key to empty array: arrays of permitted scalars pass" do
    [["foo"], [1], ["foo", "bar"], [1, 2, 3]].each do |array|
      params = ActionController::Parameters.new(id: array)
      permitted = params.allow(id: [])
      assert_equal array, permitted
    end
  end

  test "key to empty array: arrays of non-permitted scalar do not pass" do
    [[Object.new], [[]], [[1]], [{}], [{ id: "1" }]].each do |non_permitted_scalar|
      params = ActionController::Parameters.new(id: non_permitted_scalar)
      assert_equal [], params.allow(id: [])
    end
  end
end
