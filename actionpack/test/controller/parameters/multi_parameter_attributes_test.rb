require "abstract_unit"
require "action_controller/metal/strong_parameters"

class MultiParameterAttributesTest < ActiveSupport::TestCase
  test "permitted multi-parameter attribute keys" do
    params = ActionController::Parameters.new(      book: {
        "shipped_at(1i)"   => "2012",
        "shipped_at(2i)"   => "3",
        "shipped_at(3i)"   => "25",
        "shipped_at(4i)"   => "10",
        "shipped_at(5i)"   => "15",
        "published_at(1i)" => "1999",
        "published_at(2i)" => "2",
        "published_at(3i)" => "5",
        "price(1)"         => "R$",
        "price(2f)"        => "2.02"
      })

    permitted = params.permit book: [ :shipped_at, :price ]

    assert permitted.permitted?

    assert_equal "2012", permitted[:book]["shipped_at(1i)"]
    assert_equal "3", permitted[:book]["shipped_at(2i)"]
    assert_equal "25", permitted[:book]["shipped_at(3i)"]
    assert_equal "10", permitted[:book]["shipped_at(4i)"]
    assert_equal "15", permitted[:book]["shipped_at(5i)"]

    assert_equal "R$", permitted[:book]["price(1)"]
    assert_equal "2.02", permitted[:book]["price(2f)"]

    assert_nil permitted[:book]["published_at(1i)"]
    assert_nil permitted[:book]["published_at(2i)"]
    assert_nil permitted[:book]["published_at(3i)"]
  end
end
