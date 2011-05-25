require 'cases/helper'

class BCryptAuthenticatorTest < ActiveModel::TestCase
  def setup
    @auth = ActiveModel::Authenticators::BCrypt.new
    @plaintext  = "password"
    @ciphertext = @auth.crypt(@plaintext)
  end

  test "should know how to crypt a password" do
    assert_match(/^\$2a\$/, @ciphertext)
  end

  test "should successfully verify a password" do
    assert @auth.authenticate(@ciphertext, @plaintext)
  end

  test "should reject an incorrect password" do
    refute @auth.authenticate(@ciphertext, "incorrect")
  end 

end
