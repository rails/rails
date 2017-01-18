require "abstract_unit"
require "action_controller/metal/strong_parameters"

class NestedParametersPermitTest < ActiveSupport::TestCase
  def assert_filtered_out(params, key)
    assert !params.has_key?(key), "key #{key.inspect} has not been filtered out"
  end

  test "permitted nested parameters" do
    params = ActionController::Parameters.new(
      book: {
        title: "Romeo and Juliet",
        authors: [{
          name: "William Shakespeare",
          born: "1564-04-26"
        }, {
          name: "Christopher Marlowe"
        }, {
          name: %w(malicious injected names)
        }],
        details: {
          pages: 200,
          genre: "Tragedy"
        },
        id: {
          isbn: "x"
        }
      },
      magazine: "Mjallo!")

    permitted = params.permit book: [ :title, { authors: [ :name ] }, { details: :pages }, :id ]

    assert permitted.permitted?
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert_equal "William Shakespeare", permitted[:book][:authors][0][:name]
    assert_equal "Christopher Marlowe", permitted[:book][:authors][1][:name]
    assert_equal 200, permitted[:book][:details][:pages]

    assert_filtered_out permitted, :magazine
    assert_filtered_out permitted[:book], :id
    assert_filtered_out permitted[:book][:details], :genre
    assert_filtered_out permitted[:book][:authors][0], :born
    assert_filtered_out permitted[:book][:authors][2], :name
  end

  test "permitted nested parameters with a string or a symbol as a key" do
    params = ActionController::Parameters.new(
      book: {
        "authors" => [
          { name: "William Shakespeare", born: "1564-04-26" },
          { name: "Christopher Marlowe" }
        ]
      })

    permitted = params.permit book: [ { "authors" => [ :name ] } ]

    assert_equal "William Shakespeare", permitted[:book]["authors"][0][:name]
    assert_equal "William Shakespeare", permitted[:book][:authors][0][:name]
    assert_equal "Christopher Marlowe", permitted[:book]["authors"][1][:name]
    assert_equal "Christopher Marlowe", permitted[:book][:authors][1][:name]

    permitted = params.permit book: [ { authors: [ :name ] } ]

    assert_equal "William Shakespeare", permitted[:book]["authors"][0][:name]
    assert_equal "William Shakespeare", permitted[:book][:authors][0][:name]
    assert_equal "Christopher Marlowe", permitted[:book]["authors"][1][:name]
    assert_equal "Christopher Marlowe", permitted[:book][:authors][1][:name]
  end

  test "nested arrays with strings" do
    params = ActionController::Parameters.new(
      book: {
        genres: ["Tragedy"]
      })

    permitted = params.permit book: { genres: [] }
    assert_equal ["Tragedy"], permitted[:book][:genres]
  end

  test "permit may specify symbols or strings" do
    params = ActionController::Parameters.new(
      book: {
        title: "Romeo and Juliet",
        author: "William Shakespeare"
      },
      magazine: "Shakespeare Today")

    permitted = params.permit({ book: ["title", :author] }, "magazine")
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert_equal "William Shakespeare", permitted[:book][:author]
    assert_equal "Shakespeare Today", permitted[:magazine]
  end

  test "nested array with strings that should be hashes" do
    params = ActionController::Parameters.new(
      book: {
        genres: ["Tragedy"]
      })

    permitted = params.permit book: { genres: :type }
    assert_empty permitted[:book][:genres]
  end

  test "nested array with strings that should be hashes and additional values" do
    params = ActionController::Parameters.new(
      book: {
        title: "Romeo and Juliet",
        genres: ["Tragedy"]
      })

    permitted = params.permit book: [ :title, { genres: :type } ]
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert_empty permitted[:book][:genres]
  end

  test "nested string that should be a hash" do
    params = ActionController::Parameters.new(
      book: {
        genre: "Tragedy"
      })

    permitted = params.permit book: { genre: :type }
    assert_nil permitted[:book][:genre]
  end

  test "fields_for-style nested params" do
    params = ActionController::Parameters.new(
      book: {
        authors_attributes: {
          '0': { name: "William Shakespeare", age_of_death: "52" },
          '1': { name: "Unattributed Assistant" },
          '2': { name: %w(injected names) }
        }
      })
    permitted = params.permit book: { authors_attributes: [ :name ] }

    assert_not_nil permitted[:book][:authors_attributes]["0"]
    assert_not_nil permitted[:book][:authors_attributes]["1"]
    assert_empty permitted[:book][:authors_attributes]["2"]
    assert_equal "William Shakespeare", permitted[:book][:authors_attributes]["0"][:name]
    assert_equal "Unattributed Assistant", permitted[:book][:authors_attributes]["1"][:name]

    assert_equal(
      { "book" => { "authors_attributes" => { "0" => { "name" => "William Shakespeare" }, "1" => { "name" => "Unattributed Assistant" }, "2" => {} } } },
      permitted.to_h
    )

    assert_filtered_out permitted[:book][:authors_attributes]["0"], :age_of_death
  end

  test "fields_for-style nested params with negative numbers" do
    params = ActionController::Parameters.new(
      book: {
        authors_attributes: {
          '-1': { name: "William Shakespeare", age_of_death: "52" },
          '-2': { name: "Unattributed Assistant" }
        }
      })
    permitted = params.permit book: { authors_attributes: [:name] }

    assert_not_nil permitted[:book][:authors_attributes]["-1"]
    assert_not_nil permitted[:book][:authors_attributes]["-2"]
    assert_equal "William Shakespeare", permitted[:book][:authors_attributes]["-1"][:name]
    assert_equal "Unattributed Assistant", permitted[:book][:authors_attributes]["-2"][:name]

    assert_filtered_out permitted[:book][:authors_attributes]["-1"], :age_of_death
  end

  test "nested number as key" do
    params = ActionController::Parameters.new(
      product: {
        properties: {
          "0" => "prop0",
          "1" => "prop1"
        }
      })
    params = params.require(:product).permit(properties: ["0"])
    assert_not_nil        params[:properties]["0"]
    assert_nil            params[:properties]["1"]
    assert_equal "prop0", params[:properties]["0"]
  end
end
