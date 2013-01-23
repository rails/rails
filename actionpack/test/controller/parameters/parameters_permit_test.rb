require 'abstract_unit'
require 'action_dispatch/http/upload'
require 'action_controller/metal/strong_parameters'

class ParametersPermitTest < ActiveSupport::TestCase
  def assert_filtered_out(params, key)
    assert !params.has_key?(key), "key #{key.inspect} has not been filtered out"
  end

  setup do
    @params = ActionController::Parameters.new({ person: {
      age: "32", name: { first: "David", last: "Heinemeier Hansson" }
    }})

    @struct_fields = []
    %w(0 1 12).each do |number|
      ['', 'i', 'f'].each do |suffix|
        @struct_fields << "sf(#{number}#{suffix})"
      end
    end
  end

  test 'if nothing is permitted, the hash becomes empty' do
    params = ActionController::Parameters.new(id: '1234')
    permitted = params.permit
    assert permitted.permitted?
    assert permitted.empty?
  end

  test 'key: permitted scalar values' do
    values  = ['a', :a, nil]
    values += [0, 1.0, 2**128, BigDecimal.new(1)]
    values += [true, false]
    values += [Date.today, Time.now, DateTime.now]
    values += [STDOUT, StringIO.new, ActionDispatch::Http::UploadedFile.new(tempfile: __FILE__)]

    values.each do |value|
      params = ActionController::Parameters.new(id: value)
      permitted = params.permit(:id)
      assert_equal value, permitted[:id]

      @struct_fields.each do |sf|
        params = ActionController::Parameters.new(sf => value)
        permitted = params.permit(:sf)
        assert_equal value, permitted[sf]
      end
    end
  end

  test 'key: unknown keys are filtered out' do
    params = ActionController::Parameters.new(id: '1234', injected: 'injected')
    permitted = params.permit(:id)
    assert_equal '1234', permitted[:id]
    assert_filtered_out permitted, :injected
  end

  test 'key: arrays are filtered out' do
    [[], [1], ['1']].each do |array|
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

  test 'key: hashes are filtered out' do
    [{}, {foo: 1}, {foo: 'bar'}].each do |hash|
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

  test 'key: non-permitted scalar values are filtered out' do
    params = ActionController::Parameters.new(id: Object.new)
    permitted = params.permit(:id)
    assert_filtered_out permitted, :id

    @struct_fields.each do |sf|
      params = ActionController::Parameters.new(sf => Object.new)
      permitted = params.permit(:sf)
      assert_filtered_out permitted, sf
    end
  end

  test 'key: it is not assigned if not present in params' do
    params = ActionController::Parameters.new(name: 'Joe')
    permitted = params.permit(:id)
    assert !permitted.has_key?(:id)
  end

  test 'key to empty array: empty arrays pass' do
    params = ActionController::Parameters.new(id: [])
    permitted = params.permit(id: [])
    assert_equal [], permitted[:id]
  end

  test 'key to empty array: arrays of permitted scalars pass' do
    [['foo'], [1], ['foo', 'bar'], [1, 2, 3]].each do |array|
      params = ActionController::Parameters.new(id: array)
      permitted = params.permit(id: [])
      assert_equal array, permitted[:id]
    end
  end

  test 'key to empty array: permitted scalar values do not pass' do
    ['foo', 1].each do |permitted_scalar|
      params = ActionController::Parameters.new(id: permitted_scalar)
      permitted = params.permit(id: [])
      assert_filtered_out permitted, :id
    end
  end

  test 'key to empty array: arrays of non-permitted scalar do not pass' do
    [[Object.new], [[]], [[1]], [{}], [{id: '1'}]].each do |non_permitted_scalar|
      params = ActionController::Parameters.new(id: non_permitted_scalar)
      permitted = params.permit(id: [])
      assert_filtered_out permitted, :id
    end
  end

  test "fetch raises ParameterMissing exception" do
    e = assert_raises(ActionController::ParameterMissing) do
      @params.fetch :foo
    end
    assert_equal :foo, e.param
  end

  test "fetch doesnt raise ParameterMissing exception if there is a default" do
    assert_equal "monkey", @params.fetch(:foo, "monkey")
    assert_equal "monkey", @params.fetch(:foo) { "monkey" }
  end

  test "not permitted is sticky on accessors" do
    assert !@params.slice(:person).permitted?
    assert !@params[:person][:name].permitted?
    assert !@params[:person].except(:name).permitted?

    @params.each { |key, value| assert(!value.permitted?) if key == "person" }

    assert !@params.fetch(:person).permitted?

    assert !@params.values_at(:person).first.permitted?
  end

  test "permitted is sticky on accessors" do
    @params.permit!
    assert @params.slice(:person).permitted?
    assert @params[:person][:name].permitted?
    assert @params[:person].except(:name).permitted?

    @params.each { |key, value| assert(value.permitted?) if key == "person" }

    assert @params.fetch(:person).permitted?

    assert @params.values_at(:person).first.permitted?
  end

  test "not permitted is sticky on mutators" do
    assert !@params.delete_if { |k| k == "person" }.permitted?
    assert !@params.keep_if { |k,v| k == "person" }.permitted?
  end

  test "permitted is sticky on mutators" do
    @params.permit!
    assert @params.delete_if { |k| k == "person" }.permitted?
    assert @params.keep_if { |k,v| k == "person" }.permitted?
  end

  test "not permitted is sticky beyond merges" do
    assert !@params.merge(a: "b").permitted?
  end

  test "permitted is sticky beyond merges" do
    @params.permit!
    assert @params.merge(a: "b").permitted?
  end

  test "modifying the parameters" do
    @params[:person][:hometown] = "Chicago"
    @params[:person][:family] = { brother: "Jonas" }

    assert_equal "Chicago", @params[:person][:hometown]
    assert_equal "Jonas", @params[:person][:family][:brother]
  end

  test "permit state is kept on a dup" do
    @params.permit!
    assert_equal @params.permitted?, @params.dup.permitted?
  end

  test "permit is recursive" do
    @params.permit!
    assert @params.permitted?
    assert @params[:person].permitted?
    assert @params[:person][:name].permitted?
  end

  test "permitted takes a default value when Parameters.permit_all_parameters is set" do
    begin
      ActionController::Parameters.permit_all_parameters = true
      params = ActionController::Parameters.new({ person: {
        age: "32", name: { first: "David", last: "Heinemeier Hansson" }
      }})

      assert params.slice(:person).permitted?
      assert params[:person][:name].permitted?
    ensure
      ActionController::Parameters.permit_all_parameters = false
    end
  end

  test "permitting parameters as an array" do
    assert_equal "32", @params[:person].permit([ :age ])[:age]
  end
end
