# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/http/upload"
require "action_controller/metal/strong_parameters"

class ParametersPermitTest < ActiveSupport::TestCase
  def assert_filtered_out(params, key)
    assert_not params.has_key?(key), "key #{key.inspect} has not been filtered out"
  end

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

    @struct_fields = []
    %w(0 1 12).each do |number|
      ["", "i", "f"].each do |suffix|
        @struct_fields << "sf(#{number}#{suffix})"
      end
    end
  end

  def walk_permitted(params)
    params.each do |k, v|
      case v
      when ActionController::Parameters
        walk_permitted v
      when Array
        v.each { |x| walk_permitted v }
      end
    end
  end

  test "iteration should not impact permit" do
    hash = { "foo" => { "bar" => { "0" => { "baz" => "hello", "zot" => "1" } } } }
    params = ActionController::Parameters.new(hash)

    walk_permitted params

    sanitized = params[:foo].permit(bar: [:baz])
    assert_equal({ "0" => { "baz" => "hello" } }, sanitized[:bar].to_unsafe_h)
  end

  test "if nothing is permitted, the hash becomes empty" do
    params = ActionController::Parameters.new(id: "1234")
    permitted = params.permit
    assert_predicate permitted, :permitted?
    assert_empty permitted
  end

  test "key: permitted scalar values" do
    values  = ["a", :a, nil]
    values += [0, 1.0, 2**128, BigDecimal(1)]
    values += [true, false]
    values += [Date.today, Time.now, DateTime.now]
    values += [STDOUT, StringIO.new, ActionDispatch::Http::UploadedFile.new(tempfile: __FILE__),
      Rack::Test::UploadedFile.new(__FILE__)]

    values.each do |value|
      params = ActionController::Parameters.new(id: value)
      permitted = params.permit(:id)
      if value.nil?
        assert_nil permitted[:id]
      else
        assert_equal value, permitted[:id]
      end

      @struct_fields.each do |sf|
        params = ActionController::Parameters.new(sf => value)
        permitted = params.permit(:sf)
        if value.nil?
          assert_nil permitted[sf]
        else
          assert_equal value, permitted[sf]
        end
      end
    end
  end

  test "key: unknown keys are filtered out" do
    params = ActionController::Parameters.new(id: "1234", injected: "injected")
    permitted = params.permit(:id)
    assert_equal "1234", permitted[:id]
    assert_filtered_out permitted, :injected
  end

  test "key: arrays are filtered out" do
    [[], [1], ["1"]].each do |array|
      params = ActionController::Parameters.new(id: array)
      permitted = params.permit(:id)
      assert_filtered_out permitted, :id

      @struct_fields.each do |sf|
        params = ActionController::Parameters.new(sf => array)
        permitted = params.permit(:sf)
        assert_filtered_out permitted, sf
      end
    end
  end

  test "key: hashes are filtered out" do
    [{}, { foo: 1 }, { foo: "bar" }].each do |hash|
      params = ActionController::Parameters.new(id: hash)
      permitted = params.permit(:id)
      assert_filtered_out permitted, :id

      @struct_fields.each do |sf|
        params = ActionController::Parameters.new(sf => hash)
        permitted = params.permit(:sf)
        assert_filtered_out permitted, sf
      end
    end
  end

  test "key: non-permitted scalar values are filtered out" do
    params = ActionController::Parameters.new(id: Object.new)
    permitted = params.permit(:id)
    assert_filtered_out permitted, :id

    @struct_fields.each do |sf|
      params = ActionController::Parameters.new(sf => Object.new)
      permitted = params.permit(:sf)
      assert_filtered_out permitted, sf
    end
  end

  test "key: it is not assigned if not present in params" do
    params = ActionController::Parameters.new(name: "Joe")
    permitted = params.permit(:id)
    assert_not permitted.has_key?(:id)
  end

  test "key to empty array: empty arrays pass" do
    params = ActionController::Parameters.new(id: [])
    permitted = params.permit(id: [])
    assert_equal [], permitted[:id]
  end

  test "do not break params filtering on nil values" do
    params = ActionController::Parameters.new(a: 1, b: [1, 2, 3], c: nil)

    permitted = params.permit(:a, c: [], b: [])
    assert_equal 1, permitted[:a]
    assert_equal [1, 2, 3], permitted[:b]
    assert_nil permitted[:c]
  end

  test "key to empty array: arrays of permitted scalars pass" do
    [["foo"], [1], ["foo", "bar"], [1, 2, 3]].each do |array|
      params = ActionController::Parameters.new(id: array)
      permitted = params.permit(id: [])
      assert_equal array, permitted[:id]
    end
  end

  test "key to empty array: permitted scalar values do not pass" do
    ["foo", 1].each do |permitted_scalar|
      params = ActionController::Parameters.new(id: permitted_scalar)
      permitted = params.permit(id: [])
      assert_filtered_out permitted, :id
    end
  end

  test "key to empty array: arrays of non-permitted scalar do not pass" do
    [[Object.new], [[]], [[1]], [{}], [{ id: "1" }]].each do |non_permitted_scalar|
      params = ActionController::Parameters.new(id: non_permitted_scalar)
      permitted = params.permit(id: [])
      assert_filtered_out permitted, :id
    end
  end

  test "key to empty hash: arbitrary hashes are permitted" do
    params = ActionController::Parameters.new(
      username: "fxn",
      preferences: {
        scheme: "Marazul",
        font: {
          name: "Source Code Pro",
          size: 12
        },
        tabstops:   [4, 8, 12, 16],
        suspicious: [true, Object.new, false, /yo!/],
        dubious:    [{ a: :a, b: /wtf!/ }, { c: :c }],
        injected:   Object.new
      },
      hacked: 1 # not a hash
    )

    permitted = params.permit(:username, preferences: {}, hacked: {})

    assert_equal "fxn",             permitted[:username]
    assert_equal "Marazul",         permitted[:preferences][:scheme]
    assert_equal "Source Code Pro", permitted[:preferences][:font][:name]
    assert_equal 12,                permitted[:preferences][:font][:size]
    assert_equal [4, 8, 12, 16],    permitted[:preferences][:tabstops]
    assert_equal [true, false],     permitted[:preferences][:suspicious]
    assert_equal :a,                permitted[:preferences][:dubious][0][:a]
    assert_equal :c,                permitted[:preferences][:dubious][1][:c]

    assert_filtered_out permitted[:preferences][:dubious][0], :b
    assert_filtered_out permitted[:preferences], :injected
    assert_filtered_out permitted, :hacked
  end

  test "fetch raises ParameterMissing exception" do
    e = assert_raises(ActionController::ParameterMissing) do
      @params.fetch :foo
    end
    assert_equal :foo, e.param
  end

  test "fetch with a default value of a hash does not mutate the object" do
    params = ActionController::Parameters.new({})
    params.fetch :foo, {}
    assert_nil params[:foo]
  end

  test "hashes in array values get wrapped" do
    params = ActionController::Parameters.new(foo: [{}, {}])
    params[:foo].each do |hash|
      assert_not_predicate hash, :permitted?
    end
  end

  # Strong params has an optimization to avoid looping every time you read
  # a key whose value is an array and building a new object. We check that
  # optimization here.
  test "arrays are converted at most once" do
    params = ActionController::Parameters.new(foo: [{}])
    assert_same params[:foo], params[:foo]
  end

  # Strong params has an internal cache to avoid duplicated loops in the most
  # common usage pattern. See the docs of the method `converted_arrays`.
  #
  # This test checks that if we push a hash to an array (in-place modification)
  # the cache does not get fooled, the hash is still wrapped as strong params,
  # and not permitted.
  test "mutated arrays are detected" do
    params = ActionController::Parameters.new(users: [{ id: 1 }])

    permitted = params.permit(users: [:id])
    permitted[:users] << { injected: 1 }
    assert_not_predicate permitted[:users].last, :permitted?
  end

  test "fetch doesn't raise ParameterMissing exception if there is a default" do
    assert_equal "monkey", @params.fetch(:foo, "monkey")
    assert_equal "monkey", @params.fetch(:foo) { "monkey" }
  end

  test "fetch doesn't raise ParameterMissing exception if there is a default that is nil" do
    assert_nil @params.fetch(:foo, nil)
    assert_nil @params.fetch(:foo) { nil }
  end

  test "KeyError in fetch block should not be covered up" do
    params = ActionController::Parameters.new
    e = assert_raises(KeyError) do
      params.fetch(:missing_key) { {}.fetch(:also_missing) }
    end
    assert_match(/:also_missing$/, e.message)
  end

  test "not permitted is sticky beyond merges" do
    assert_not_predicate @params.merge(a: "b"), :permitted?
  end

  test "permitted is sticky beyond merges" do
    @params.permit!
    assert_predicate @params.merge(a: "b"), :permitted?
  end

  test "merge with parameters" do
    other_params = ActionController::Parameters.new(id: "1234").permit!
    merged_params = @params.merge(other_params)

    assert merged_params[:id]
  end

  test "not permitted is sticky beyond merge!" do
    assert_not_predicate @params.merge!(a: "b"), :permitted?
  end

  test "permitted is sticky beyond merge!" do
    @params.permit!
    assert_predicate @params.merge!(a: "b"), :permitted?
  end

  test "merge! with parameters" do
    other_params = ActionController::Parameters.new(id: "1234").permit!
    @params.merge!(other_params)

    assert_equal "1234", @params[:id]
    assert_equal "32", @params[:person][:age]
  end

  test "#reverse_merge with parameters" do
    default_params = ActionController::Parameters.new(id: "1234", person: {}).permit!
    merged_params = @params.reverse_merge(default_params)

    assert_equal "1234", merged_params[:id]
    assert_not_predicate merged_params[:person], :empty?
  end

  test "#with_defaults is an alias of reverse_merge" do
    default_params = ActionController::Parameters.new(id: "1234", person: {}).permit!
    merged_params = @params.with_defaults(default_params)

    assert_equal "1234", merged_params[:id]
    assert_not_predicate merged_params[:person], :empty?
  end

  test "not permitted is sticky beyond reverse_merge" do
    assert_not_predicate @params.reverse_merge(a: "b"), :permitted?
  end

  test "permitted is sticky beyond reverse_merge" do
    @params.permit!
    assert_predicate @params.reverse_merge(a: "b"), :permitted?
  end

  test "#reverse_merge! with parameters" do
    default_params = ActionController::Parameters.new(id: "1234", person: {}).permit!
    @params.reverse_merge!(default_params)

    assert_equal "1234", @params[:id]
    assert_not_predicate @params[:person], :empty?
  end

  test "#with_defaults! is an alias of reverse_merge!" do
    default_params = ActionController::Parameters.new(id: "1234", person: {}).permit!
    @params.with_defaults!(default_params)

    assert_equal "1234", @params[:id]
    assert_not_predicate @params[:person], :empty?
  end

  test "modifying the parameters" do
    @params[:person][:hometown] = "Chicago"
    @params[:person][:family] = { brother: "Jonas" }

    assert_equal "Chicago", @params[:person][:hometown]
    assert_equal "Jonas", @params[:person][:family][:brother]
  end

  test "permit! is recursive" do
    @params[:nested_array] = [[{ x: 2, y: 3 }, { x: 21, y: 42 }]]
    @params.permit!
    assert_predicate @params, :permitted?
    assert_predicate @params[:person], :permitted?
    assert_predicate @params[:person][:name], :permitted?
    assert_predicate @params[:person][:addresses][0], :permitted?
    assert_predicate @params[:nested_array][0][0], :permitted?
    assert_predicate @params[:nested_array][0][1], :permitted?
  end

  test "permitted takes a default value when Parameters.permit_all_parameters is set" do
    ActionController::Parameters.permit_all_parameters = true
    params = ActionController::Parameters.new(person: {
      age: "32", name: { first: "David", last: "Heinemeier Hansson" }
    })

    assert_predicate params.slice(:person), :permitted?
    assert_predicate params[:person][:name], :permitted?
  ensure
    ActionController::Parameters.permit_all_parameters = false
  end

  test "permitting parameters as an array" do
    assert_equal "32", @params[:person].permit([ :age ])[:age]
  end

  test "to_h raises UnfilteredParameters on unfiltered params" do
    assert_raises(ActionController::UnfilteredParameters) do
      @params.to_h
    end
  end

  test "to_h returns converted hash on permitted params" do
    @params.permit!

    assert_instance_of ActiveSupport::HashWithIndifferentAccess, @params.to_h
    assert_not_kind_of ActionController::Parameters, @params.to_h
  end

  test "to_h returns converted hash when .permit_all_parameters is set" do
    ActionController::Parameters.permit_all_parameters = true
    params = ActionController::Parameters.new(crab: "Senjougahara Hitagi")

    assert_instance_of ActiveSupport::HashWithIndifferentAccess, params.to_h
    assert_not_kind_of ActionController::Parameters, params.to_h
    assert_equal({ "crab" => "Senjougahara Hitagi" }, params.to_h)
  ensure
    ActionController::Parameters.permit_all_parameters = false
  end

  test "to_hash raises UnfilteredParameters on unfiltered params" do
    assert_raises(ActionController::UnfilteredParameters) do
      @params.to_hash
    end
  end

  test "to_hash returns converted hash on permitted params" do
    @params.permit!

    assert_instance_of Hash, @params.to_hash
    assert_not_kind_of ActionController::Parameters, @params.to_hash
  end

  test "parameters can be implicit converted to Hash" do
    params = ActionController::Parameters.new
    params.permit!

    assert_equal({ a: 1 }, { a: 1 }.merge!(params))
  end

  test "to_hash returns converted hash when .permit_all_parameters is set" do
    ActionController::Parameters.permit_all_parameters = true
    params = ActionController::Parameters.new(crab: "Senjougahara Hitagi")

    assert_instance_of Hash, params.to_hash
    assert_not_kind_of ActionController::Parameters, params.to_hash
    assert_equal({ "crab" => "Senjougahara Hitagi" }, params.to_hash)
    assert_equal({ "crab" => "Senjougahara Hitagi" }, params)
  ensure
    ActionController::Parameters.permit_all_parameters = false
  end

  test "to_unsafe_h returns unfiltered params" do
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, @params.to_unsafe_h
    assert_not_kind_of ActionController::Parameters, @params.to_unsafe_h
  end

  test "to_unsafe_h returns unfiltered params even after accessing few keys" do
    params = ActionController::Parameters.new("f" => { "language_facet" => ["Tibetan"] })
    expected = { "f" => { "language_facet" => ["Tibetan"] } }

    assert_instance_of ActionController::Parameters, params["f"]
    assert_equal expected, params.to_unsafe_h
  end

  test "to_unsafe_h does not mutate the parameters" do
    params = ActionController::Parameters.new("f" => { "language_facet" => ["Tibetan"] })
    params[:f]

    params.to_unsafe_h

    assert_not_predicate params, :permitted?
    assert_not_predicate params[:f], :permitted?
  end

  test "to_h only deep dups Ruby collections" do
    company = Class.new do
      attr_reader :dupped
      def dup; @dupped = true; end
    end.new

    params = ActionController::Parameters.new(prem: { likes: %i( dancing ) })
    assert_equal({ "prem" => { "likes" => %i( dancing ) } }, params.permit!.to_h)

    params = ActionController::Parameters.new(companies: [ company, :acme ])
    assert_equal({ "companies" => [ company, :acme ] }, params.permit!.to_h)
    assert_not company.dupped
  end

  test "to_unsafe_h only deep dups Ruby collections" do
    company = Class.new do
      attr_reader :dupped
      def dup; @dupped = true; end
    end.new

    params = ActionController::Parameters.new(prem: { likes: %i( dancing ) })
    assert_equal({ "prem" => { "likes" => %i( dancing ) } }, params.to_unsafe_h)

    params = ActionController::Parameters.new(companies: [ company, :acme ])
    assert_equal({ "companies" => [ company, :acme ] }, params.to_unsafe_h)
    assert_not company.dupped
  end

  test "include? returns true when the key is present" do
    assert @params.include? :person
    assert @params.include? "person"
    assert_not @params.include? :gorilla
  end

  test "scalar values should be filtered when array or hash is specified" do
    params = ActionController::Parameters.new(foo: "bar")

    assert params.permit(:foo).has_key?(:foo)
    assert_not params.permit(foo: []).has_key?(:foo)
    assert_not params.permit(foo: [:bar]).has_key?(:foo)
    assert_not params.permit(foo: :bar).has_key?(:foo)
  end

  test "#permitted? is false by default" do
    params = ActionController::Parameters.new

    assert_equal false, params.permitted?
  end
end
