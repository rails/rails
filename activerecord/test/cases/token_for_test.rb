# frozen_string_literal: true

require "cases/helper"
require "models/matey"
require "models/user"
require "models/cpk"
require "models/room"
require "active_support/message_verifier"

class TokenForTest < ActiveRecord::TestCase
  class User < ::User
    generates_token_for :lookup

    generates_token_for :password_reset, expires_in: 15.minutes do
      password_digest.to_s[-(31 + 22), 10] # first 10 characters of BCrypt salt
    end

    generates_token_for :snapshot do
      { updated_at: updated_at }
    end
  end

  setup do
    @original_verifier = ActiveRecord::Base.generated_token_verifier
    ActiveRecord::Base.generated_token_verifier = ActiveSupport::MessageVerifier.new("secret")

    @user = User.create!(password_digest: "$2a$4$#{"x" * 22}#{"y" * 31}")
    @lookup_token = @user.generate_token_for(:lookup)
    @password_reset_token = @user.generate_token_for(:password_reset)
  end

  teardown do
    ActiveRecord::Base.generated_token_verifier = @original_verifier
  end

  test "finds record by token" do
    assert_equal @user, User.find_by_token_for(:lookup, @lookup_token)
    assert_equal @user, User.find_by_token_for!(:lookup, @lookup_token)
  end

  test "returns nil when record is not found" do
    @user.destroy
    assert_nil User.find_by_token_for(:lookup, @lookup_token)
  end

  test "raises on bang when record is not found" do
    @user.destroy
    assert_raises(ActiveRecord::RecordNotFound) do
      User.find_by_token_for!(:lookup, @lookup_token)
    end
  end

  test "raises when token definition does not exist" do
    assert_raises { User.find_by_token_for(:bad, @lookup_token) }
  end

  test "does not find record when token is invalid" do
    assert_nil User.find_by_token_for(:lookup, "bad")
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      User.find_by_token_for!(:lookup, "bad")
    end
  end

  test "does not find record when token is for a different purpose" do
    assert_nil User.find_by_token_for(:password_reset, @lookup_token)
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      User.find_by_token_for!(:password_reset, @lookup_token)
    end
  end

  test "finds record when token has not expired and embedded data has not changed" do
    assert_equal @user, User.find_by_token_for(:password_reset, @password_reset_token)
  end

  test "does not find record when token has expired" do
    travel 1.day
    assert_nil User.find_by_token_for(:password_reset, @password_reset_token)
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      User.find_by_token_for!(:password_reset, @password_reset_token)
    end
  end

  test "tokens do not expire by default" do
    travel 1000.years
    assert_equal @user, User.find_by_token_for(:lookup, @lookup_token)
  end

  test "does not find record when expires_in is different" do
    User.generates_token_for :lookup, expires_in: 1.year

    assert_nil User.find_by_token_for(:lookup, @lookup_token)
    new_lookup_token = @user.generate_token_for(:lookup)
    assert_equal @user, User.find_by_token_for(:lookup, new_lookup_token)
  ensure
    User.generates_token_for :lookup
  end

  test "does not find record when embedded data is different" do
    @user.update!(password: "new password")
    assert_nil User.find_by_token_for(:password_reset, @password_reset_token)
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      User.find_by_token_for!(:password_reset, @password_reset_token)
    end
  end

  test "supports JSON-serializable embedded data" do
    snapshot_token = @user.generate_token_for(:snapshot)
    assert_equal @user, User.find_by_token_for(:snapshot, snapshot_token)
    @user.touch(time: @user.updated_at.advance(seconds: 1))
    assert_nil User.find_by_token_for(:snapshot, snapshot_token)
  end

  test "finds record through relation" do
    assert_equal @user, User.where("1=1").find_by_token_for(:lookup, @lookup_token)
    assert_nil User.where("1=0").find_by_token_for(:lookup, @lookup_token)
  end

  test "finds record through subclass" do
    subclass = Class.new(User)
    subclassed_user = subclass.find_by_token_for(:lookup, @lookup_token)

    assert_instance_of subclass, subclassed_user
    assert_equal @user.id, subclassed_user.id
  end

  test "subclasses can redefine tokens" do
    subclass = Class.new(User) do
      generates_token_for :lookup
    end
    subclassed_user = subclass.find(@user.id)
    subclassed_lookup_token = subclassed_user.generate_token_for(:lookup)

    assert_equal subclassed_user, subclass.find_by_token_for(:lookup, subclassed_lookup_token)
    assert_nil subclass.find_by_token_for(:lookup, @lookup_token)
    assert_nil User.find_by_token_for(:lookup, subclassed_lookup_token)
  end

  test "finds record with a custom primary key" do
    custom_pk = Class.new(User) do
      self.primary_key = "auth_token"
    end
    custom_pk_user = custom_pk.find(@user.auth_token)
    custom_pk_lookup_token = custom_pk_user.generate_token_for(:lookup)

    assert_equal custom_pk_user, custom_pk.find_by_token_for(:lookup, custom_pk_lookup_token)
    assert_nil custom_pk.find_by_token_for(:lookup, @lookup_token)
  end

  test "finds record with a composite primary key" do
    book = Cpk::Book.create!(id: [1, 3], shop_id: 2)
    token = book.generate_token_for(:test)

    assert_equal book, Cpk::Book.find_by_token_for(:test, token)
  end

  test "raises when no primary key has been declared" do
    no_pk = Class.new(Matey) do
      generates_token_for :parley
    end

    assert_raises(ActiveRecord::UnknownPrimaryKey) do
      no_pk.find_by_token_for(:parley, "this token will not be checked")
    end
  end
end
