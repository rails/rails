require 'action_controller/metal/strong_parameters'

class NestedParametersTest < ActiveSupport::TestCase
  test "permitted nested parameters" do
    params = ActionController::Parameters.new({
      book: {
        title: "Romeo and Juliet",
        authors: [{
          name: "William Shakespeare",
          born: "1564-04-26"
        }, {
          name: "Christopher Marlowe"
        }],
        details: {
          pages: 200,
          genre: "Tragedy"
        }
      },
      magazine: "Mjallo!"
    })

    permitted = params.permit book: [ :title, { authors: [ :name ] }, { details: :pages } ]

    assert permitted.permitted?
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert_equal "William Shakespeare", permitted[:book][:authors][0][:name]
    assert_equal "Christopher Marlowe", permitted[:book][:authors][1][:name]
    assert_equal 200, permitted[:book][:details][:pages]
    assert_nil permitted[:book][:details][:genre]
    assert_nil permitted[:book][:authors][1][:born]
    assert_nil permitted[:magazine]
  end

  test "nested arrays with strings" do
    params = ActionController::Parameters.new({
      :book => {
        :genres => ["Tragedy"]
      }
    })

    permitted = params.permit :book => :genres
    assert_equal ["Tragedy"], permitted[:book][:genres]
  end

  test "permit may specify symbols or strings" do
    params = ActionController::Parameters.new({
      :book => {
        :title => "Romeo and Juliet",
        :author => "William Shakespeare"
      },
      :magazine => "Shakespeare Today"
    })

    permitted = params.permit({:book => ["title", :author]}, "magazine")
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert_equal "William Shakespeare", permitted[:book][:author]
    assert_equal "Shakespeare Today", permitted[:magazine]
  end

  test "nested array with strings that should be hashes" do
    params = ActionController::Parameters.new({
      book: {
        genres: ["Tragedy"]
      }
    })

    permitted = params.permit book: { genres: :type }
    assert_empty permitted[:book][:genres]
  end

  test "nested array with strings that should be hashes and additional values" do
    params = ActionController::Parameters.new({
      book: {
        title: "Romeo and Juliet",
        genres: ["Tragedy"]
      }
    })

    permitted = params.permit book: [ :title, { genres: :type } ]
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert_empty permitted[:book][:genres]
  end

  test "nested string that should be a hash" do
    params = ActionController::Parameters.new({
      book: {
        genre: "Tragedy"
      }
    })

    permitted = params.permit book: { genre: :type }
    assert_nil permitted[:book][:genre]
  end
end
