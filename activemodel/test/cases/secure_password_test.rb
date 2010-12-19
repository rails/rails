require 'cases/helper'
require 'models/user'

class SecurePasswordTest < ActiveModel::TestCase
  setup do
    @user = User.new
  end

  test "password must be present" do
    assert !@user.valid?
    assert_equal 1, @user.errors.size
  end
  
  test "password must match confirmation" do
    @user.password = "thiswillberight"
    @user.password_confirmation = "wrong"
    
    assert !@user.valid?
    
    @user.password_confirmation = "thiswillberight"
    
    assert @user.valid?
  end
  
  test "password must pass validation rules" do
    @user.password = "password"
    assert !@user.valid?
    
    @user.password = "short"
    assert !@user.valid?
    
    @user.password = "plentylongenough"
    assert @user.valid?
  end
  
  test "too weak passwords" do
    @user.password = "012345"
    assert !@user.valid?
    assert_equal ["must be longer than 6 characters"], @user.errors[:password]

    @user.password = "password"
    assert !@user.valid?
    assert_equal ["is too weak and common"], @user.errors[:password]
    
    @user.password = "d9034rfjlakj34RR$!!"
    assert @user.valid?
  end
  
  test "authenticate" do
    @user.password = "secret"
    
    assert !@user.authenticate("wrong")
    assert @user.authenticate("secret")
  end
end