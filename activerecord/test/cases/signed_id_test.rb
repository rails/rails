# frozen_string_literal: true

require "cases/helper"
require "models/account"
require "models/company"
require "models/toy"
require "models/matey"

SIGNED_ID_VERIFIER_TEST_SECRET = -> { "This is normally set by the railtie initializer when used with Rails!" }

ActiveRecord::Base.signed_id_verifier_secret = SIGNED_ID_VERIFIER_TEST_SECRET

class SignedIdTest < ActiveRecord::TestCase
  class GetSignedIDInCallback < ActiveRecord::Base
    self.table_name = "accounts"
    after_create :set_signed_id
    attr_reader :signed_id_from_callback

    private
      def set_signed_id
        @signed_id_from_callback = signed_id
      end
  end

  fixtures :accounts, :toys, :companies

  setup do
    @account = Account.first
    @toy = Toy.first
  end

  test "find signed record" do
    assert_equal @account, Account.find_signed(@account.signed_id)
  end

  test "find signed record on relation" do
    assert_equal @account, Account.where("1=1").find_signed(@account.signed_id)

    assert_nil Account.where("1=0").find_signed(@account.signed_id)
  end

  test "find signed record with custom primary key" do
    assert_equal @toy, Toy.find_signed(@toy.signed_id)
  end

  test "find signed record for single table inheritance (STI Models)" do
    assert_equal Company.first, Company.find_signed(Company.first.signed_id)
  end

  test "find signed record raises UnknownPrimaryKey when a model has no primary key" do
    error = assert_raises(ActiveRecord::UnknownPrimaryKey) do
      Matey.find_signed("this will not be even verified")
    end
    assert_equal "Unknown primary key for table mateys in model Matey.", error.message
  end

  test "find signed record with a bang" do
    assert_equal @account, Account.find_signed!(@account.signed_id)
  end

  test "find signed record with a bang on relation" do
    assert_equal @account, Account.where("1=1").find_signed!(@account.signed_id)

    assert_raises(ActiveRecord::RecordNotFound) do
      Account.where("1=0").find_signed!(@account.signed_id)
    end
  end

  test "find signed record with a bang with custom primary key" do
    assert_equal @toy, Toy.find_signed!(@toy.signed_id)
  end

  test "find signed record with a bang for single table inheritance (STI Models)" do
    assert_equal Company.first, Company.find_signed!(Company.first.signed_id)
  end

  test "fail to find record from broken signed id" do
    assert_nil Account.find_signed("this won't find anything")
  end

  test "find signed record within expiration duration" do
    assert_equal @account, Account.find_signed(@account.signed_id(expires_in: 1.minute))
  end

  test "fail to find signed record within expiration duration" do
    signed_id = @account.signed_id(expires_in: 1.minute)
    travel 2.minutes
    assert_nil Account.find_signed(signed_id)
  end

  test "fail to find record from that has since been destroyed" do
    signed_id = @account.signed_id(expires_in: 1.minute)
    @account.destroy
    assert_nil Account.find_signed signed_id
  end

  test "find signed record within expiration time" do
    assert_equal @account, Account.find_signed(@account.signed_id(expires_at: 1.minute.from_now))
  end

  test "fail to find signed record within expiration time" do
    signed_id = @account.signed_id(expires_at: 1.minute.from_now)
    travel 2.minutes
    assert_nil Account.find_signed(signed_id)
  end

  test "find signed record with purpose" do
    assert_equal @account, Account.find_signed(@account.signed_id(purpose: :v1), purpose: :v1)
  end

  test "fail to find signed record with purpose" do
    assert_nil Account.find_signed(@account.signed_id(purpose: :v1))

    assert_nil Account.find_signed(@account.signed_id(purpose: :v1), purpose: :v2)
  end

  test "finding record from broken signed id raises on the bang" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      Account.find_signed! "this will blow up"
    end
  end

  test "find signed record with a bang within expiration duration" do
    assert_equal @account, Account.find_signed!(@account.signed_id(expires_in: 1.minute))
  end

  test "finding signed record outside expiration duration raises on the bang" do
    signed_id = @account.signed_id(expires_in: 1.minute)
    travel 2.minutes

    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      Account.find_signed!(signed_id)
    end
  end

  test "finding signed record that has been destroyed raises on the bang" do
    signed_id = @account.signed_id(expires_in: 1.minute)
    @account.destroy

    assert_raises(ActiveRecord::RecordNotFound) do
      Account.find_signed!(signed_id)
    end
  end

  test "find signed record with bang with purpose" do
    assert_equal @account, Account.find_signed!(@account.signed_id(purpose: :v1), purpose: :v1)
  end

  test "find signed record with bang with purpose raises" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      Account.find_signed!(@account.signed_id(purpose: :v1))
    end

    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      Account.find_signed!(@account.signed_id(purpose: :v1), purpose: :v2)
    end
  end

  test "fail to work without a signed_id_verifier_secret" do
    ActiveRecord::Base.signed_id_verifier_secret = nil
    Account.instance_variable_set :@signed_id_verifier, nil

    assert_raises(ArgumentError) do
      @account.signed_id
    end
  ensure
    ActiveRecord::Base.signed_id_verifier_secret = SIGNED_ID_VERIFIER_TEST_SECRET
  end

  test "fail to work without when signed_id_verifier_secret lambda is nil" do
    ActiveRecord::Base.signed_id_verifier_secret = -> { nil }
    Account.instance_variable_set :@signed_id_verifier, nil

    assert_raises(ArgumentError) do
      @account.signed_id
    end
  ensure
    ActiveRecord::Base.signed_id_verifier_secret = SIGNED_ID_VERIFIER_TEST_SECRET
  end

  test "always output url_safe" do
    signed_id = @account.signed_id(purpose: "~~~~~~~~~")
    assert_not signed_id.include?("+")
  end

  test "use a custom verifier" do
    old_verifier = Account.signed_id_verifier
    Account.signed_id_verifier = ActiveSupport::MessageVerifier.new("sekret")
    assert_not_equal ActiveRecord::Base.signed_id_verifier, Account.signed_id_verifier
    assert_equal @account, Account.find_signed(@account.signed_id)
  ensure
    Account.signed_id_verifier = old_verifier
  end

  test "on_rotation callback using custom verifier" do
    old_verifier = Account.signed_id_verifier

    Account.signed_id_verifier = ActiveSupport::MessageVerifier.new("old secret")
    old_account_signed_id = @account.signed_id
    on_rotation_is_called = false
    Account.signed_id_verifier = ActiveSupport::MessageVerifier.new("new secret", on_rotation: -> { on_rotation_is_called = true })
    Account.signed_id_verifier.rotate("old secret")
    Account.find_signed(old_account_signed_id)
    assert on_rotation_is_called
  ensure
    Account.signed_id_verifier = old_verifier
  end

  test "on_rotation callback using find_signed & find_signed!" do
    old_verifier = Account.signed_id_verifier

    Account.signed_id_verifier = ActiveSupport::MessageVerifier.new("old secret")
    old_account_signed_id = @account.signed_id
    Account.signed_id_verifier = ActiveSupport::MessageVerifier.new("new secret")
    Account.signed_id_verifier.rotate("old secret")
    on_rotation_is_called = false
    assert Account.find_signed(old_account_signed_id, on_rotation: -> { on_rotation_is_called = true })
    assert on_rotation_is_called
    on_rotation_is_called = false
    assert Account.find_signed!(old_account_signed_id, on_rotation: -> { on_rotation_is_called = true })
    assert on_rotation_is_called
  ensure
    Account.signed_id_verifier = old_verifier
  end

  test "cannot get a signed ID for a new record" do
    assert_raises ArgumentError, match: /Cannot get a signed_id for a new record/ do
      Account.new.signed_id
    end
  end

  test "can get a signed ID in an after_create" do
    assert_not_nil GetSignedIDInCallback.create.signed_id_from_callback
  end
end
