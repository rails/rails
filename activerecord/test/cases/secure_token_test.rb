# frozen_string_literal: true

require "cases/helper"
require "models/user"

class SecureTokenTest < ActiveRecord::TestCase
  setup do
    @user = User.new
  end

  def test_token_values_are_generated_for_specified_attributes_and_persisted_on_save
    @user.save
    assert_not_nil @user.token
    assert_not_nil @user.auth_token
    assert_equal 24, @user.token.size
    assert_equal 36, @user.auth_token.size
  end

  def test_generating_token_on_initialize_does_not_affect_reading_from_the_column
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "users"
      has_secure_token on: :initialize
    end

    token = "abc123"

    user = model.create!(token: token)

    assert_equal token, user.token
    assert_equal token, user.reload.token
    assert_equal token, model.find(user.id).token
  end

  def test_generating_token_on_initialize_happens_only_once
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "users"
      has_secure_token on: :initialize
    end

    token = "    "

    user = model.new
    user.update!(token: token)

    assert_equal token, user.token
    assert_equal token, user.reload.token
    assert_equal token, model.find(user.id).token
  end

  def test_generating_token_on_initialize_is_skipped_if_column_was_not_selected
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "users"
      has_secure_token on: :initialize
    end

    model.create!
    assert_nothing_raised do
      model.select(:id).last
    end
  end

  def test_regenerating_the_secure_token
    @user.save
    old_token = @user.token
    old_auth_token = @user.auth_token
    @user.regenerate_token
    @user.regenerate_auth_token

    assert_not_equal @user.token, old_token
    assert_not_equal @user.auth_token, old_auth_token

    assert_equal 24, @user.token.size
    assert_equal 36, @user.auth_token.size
  end

  def test_token_value_not_overwritten_when_present
    @user.token = "custom-secure-token"
    @user.save

    assert_equal "custom-secure-token", @user.token
  end

  def test_token_length_cannot_be_less_than_24_characters
    assert_raises(ActiveRecord::SecureToken::MinimumLengthError) do
      @user.class_eval do
        has_secure_token :not_valid_token, length: 12
      end
    end
  end

  def test_token_on_callback
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "users"
      has_secure_token on: :initialize
    end

    user = model.new

    assert_predicate user.token, :present?
  end

  def test_token_calls_the_setter_method
    model = Class.new(ActiveRecord::Base) do
      self.table_name = "users"
      has_secure_token on: :initialize

      attr_accessor :modified_token

      def token=(value)
        super
        self.modified_token = "#{value}_modified"
      end
    end

    user = model.new

    assert_equal "#{user.token}_modified", user.modified_token
  end
end
