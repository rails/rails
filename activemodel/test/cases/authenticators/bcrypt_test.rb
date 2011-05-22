require 'cases/helper'

class BCryptAuthenticatorTest < ActiveModel::TestCase
  def setup
    @plaintext  = "password"
    @ciphertext = ActiveModel::Authenticators::BCrypt.crypt(@plaintext)
  end

  test "should know how to crypt a password" do
    assert_match /^\$2a\$/, @ciphertext
  end

  test "should successfully verify a password" do
    assert ActiveModel::Authenticators::BCrypt.authenticate(@ciphertext, @plaintext)
  end

  test "should reject an incorrect password" do
    refute ActiveModel::Authenticators::BCrypt.authenticate(@ciphertext, "incorrect")
  end 

end
