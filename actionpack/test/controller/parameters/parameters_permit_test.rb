require 'abstract_unit'
require 'action_controller/metal/strong_parameters'

class ParametersPermitTest < ActiveSupport::TestCase
  setup do
    @params = ActionController::Parameters.new({ person: { 
      age: "32", name: { first: "David", last: "Heinemeier Hansson" }
    }})
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

  test "permitted is sticky on accessors" do
    assert !@params.slice(:person).permitted?
    assert !@params[:person][:name].permitted?

    @params.each { |key, value| assert(value.permitted?) if key == :person }

    assert !@params.fetch(:person).permitted?

    assert !@params.values_at(:person).first.permitted?
  end

  test "permitted is sticky on mutators" do
    assert !@params.delete_if { |k| k == :person }.permitted?
    assert !@params.keep_if { |k,v| k == :person }.permitted?
  end

  test "permitted is sticky beyond merges" do
    assert !@params.merge(a: "b").permitted?
  end

  test "modifying the parameters" do
    @params[:person][:hometown] = "Chicago"
    @params[:person][:family] = { brother: "Jonas" }

    assert_equal "Chicago", @params[:person][:hometown]
    assert_equal "Jonas", @params[:person][:family][:brother]
  end

  test "permitting parameters that are not there should not include the keys" do
    assert !@params.permit(:person, :funky).has_key?(:funky)
  end

  test "permit state is kept on a dup" do
    @params.permit!
    assert_equal @params.permitted?, @params.dup.permitted?
  end
end
