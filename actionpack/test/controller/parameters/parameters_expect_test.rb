# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/http/upload"
require "action_controller/metal/strong_parameters"

class ParametersExpectTest < ActiveSupport::TestCase
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
    permitted = @params.expect(person: [:age, :name, :addresses])

    assert_equal({ "age" => "32" }, permitted.to_unsafe_h)
  end

  test "key to hash: returns permitted params" do
    permitted = @params.expect(person: { name: [:first, :last] })

    assert_equal({ "name" => { "first" => "David", "last" => "Heinemeier Hansson" } }, permitted.to_h)
  end

  test "key to empty hash: permits all params" do
    permitted = @params.expect(person: {})

    assert_equal({ "age" => "32", "name" => { "first" => "David", "last" => "Heinemeier Hansson" }, "addresses" => [{ "city" => "Chicago", "state" => "Illinois" }] }, permitted.to_h)
    assert_predicate permitted, :permitted?
  end

  test "keys to arrays: returns permitted params in hash key order" do
    name, addresses = @params[:person].expect(name: [:first, :last], addresses: [[:city]])

    assert_equal({ "first" => "David", "last" => "Heinemeier Hansson" }, name.to_h)
    assert_equal({ "city" => "Chicago" }, addresses.first.to_h)
  end

  test "key to array of keys: raises when params is an array" do
    params = ActionController::Parameters.new(name: "Martin", pies: [{ flavor: "pumpkin" }])

    assert_raises(ActionController::ParameterMissing) do
      params.expect(pies: [:flavor])
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(pies: [:flavor])
    end
  end

  test "key to explicit array: returns permitted array" do
    params = ActionController::Parameters.new(name: "Martin", pies: [{ flavor: "pumpkin" }, { flavor: "chicken pot" }])
    pies = params.expect(pies: [[:flavor]])

    assert_equal({ "flavor" => "pumpkin" }, pies[0].to_h)
    assert_equal({ "flavor" => "chicken pot" }, pies[1].to_h)
  end

  test "key to explicit array: returns array when params is a hash" do
    params = ActionController::Parameters.new(name: "Martin", pies: { flavor: "pumpkin" })

    assert_raises(ActionController::ParameterMissing) do
      params.expect(pies: [[:flavor]])
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(pies: [[:flavor]])
    end
  end

  test "key to explicit array: returns empty array when params empty array" do
    params = ActionController::Parameters.new(name: "Martin", pies: [])

    assert_raises(ActionController::ParameterMissing) do
      params.expect(pies: [[:flavor]])
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(pies: [[:flavor]])
    end
  end

  test "key to mixed array: returns permitted params" do
    permitted = @params.expect(person: [ :age, name: [:first, :last] ])

    assert_equal({ "age" => "32", "name" => { "first" => "David", "last" => "Heinemeier Hansson" } }, permitted.to_h)
  end

  test "chain of keys: returns permitted params" do
    params = ActionController::Parameters.new(person: { name: "David" })
    name = params.expect(person: :name).expect(:name)

    assert_equal "David", name
  end

  test "array of key: returns single permitted param" do
    params = ActionController::Parameters.new(a: 1, b: 2)
    a = params.expect(:a)

    assert_equal 1, a
  end

  test "array of keys: returns multiple permitted params" do
    params = ActionController::Parameters.new(a: 1, b: 2)
    a, b = params.expect(:a, :b)

    assert_equal 1, a
    assert_equal 2, b
  end

  test "key: raises ParameterMissing on nil, blank, non-scalar or non-permitted type" do
    values  = [nil, "", {}, [], [1], { foo: "bar" }, Object.new]
    values.each do |value|
      params = ActionController::Parameters.new(id: value)

      assert_raises(ActionController::ParameterMissing) do
        params.expect(:id)
      end
      assert_raises(ActionController::ExpectedParameterMissing) do
        params.expect!(pies: [[:flavor]])
      end
    end
  end

  test "key: raises ParameterMissing if not present in params" do
    params = ActionController::Parameters.new(name: "Joe")
    assert_raises(ActionController::ParameterMissing) do
      params.expect(:id)
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(:id)
    end
  end

  test "key to empty array: raises ParameterMissing on empty" do
    params = ActionController::Parameters.new(ids: [])
    assert_raises(ActionController::ParameterMissing) do
      params.expect(ids: [])
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(ids: [])
    end
  end

  test "key to empty array: raises ParameterMissing on scalar" do
    params = ActionController::Parameters.new(person: 1)
    assert_raises(ActionController::ParameterMissing) do
      params.expect(ids: [])
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(ids: [])
    end
  end

  test "key to non-scalar: raises ParameterMissing on scalar" do
    params = ActionController::Parameters.new(foo: "bar")

    assert_raises(ActionController::ParameterMissing) do
      params.expect(foo: [])
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(foo: [])
    end
    assert_raises(ActionController::ParameterMissing) do
      params.expect(foo: [:bar])
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(foo: [:bar])
    end
    assert_raises(ActionController::ParameterMissing) do
      params.expect(foo: :bar)
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(foo: :bar)
    end
  end

  test "key to empty hash: raises ParameterMissing on empty" do
    params = ActionController::Parameters.new(person: {})

    assert_raises(ActionController::ParameterMissing) do
      params.expect(person: {})
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(person: {})
    end
  end

  test "key to empty hash: raises ParameterMissing on scalar" do
    params = ActionController::Parameters.new(person: 1)

    assert_raises(ActionController::ParameterMissing) do
      params.expect(person: {})
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!(person: {})
    end
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

      assert_equal value, params.expect(:id)
    end
  end

  test "key: unknown keys are filtered out" do
    params = ActionController::Parameters.new(id: "1234", injected: "injected")

    assert_equal "1234", params.expect(:id)
  end

  test "array of keys: raises ParameterMissing when one is missing" do
    params = ActionController::Parameters.new(a: 1)

    assert_raises(ActionController::ParameterMissing) do
      params.expect([:a, :b])
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!([:a, :b])
    end
  end

  test "array of keys: raises ParameterMissing when one is non-scalar" do
    params = ActionController::Parameters.new(a: 1, b: [])

    assert_raises(ActionController::ParameterMissing) do
      params.expect([:a, :b])
    end
    assert_raises(ActionController::ExpectedParameterMissing) do
      params.expect!([:a, :b])
    end
  end

  test "key to empty array: arrays of permitted scalars pass" do
    [["foo"], [1], ["foo", "bar"], [1, 2, 3]].each do |array|
      params = ActionController::Parameters.new(id: array)
      permitted = params.expect(id: [])
      assert_equal array, permitted
    end
  end

  test "key to empty array: arrays of non-permitted scalar do not pass" do
    [[Object.new], [[]], [[1]], [{}], [{ id: "1" }]].each do |non_permitted_scalar|
      params = ActionController::Parameters.new(id: non_permitted_scalar)
      assert_raises(ActionController::ParameterMissing) do
        params.expect(id: [])
      end
      assert_raises(ActionController::ExpectedParameterMissing) do
        params.expect!(id: [])
      end
    end
  end
end
