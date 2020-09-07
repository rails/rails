# frozen_string_literal: true

require "cases/helper"
require "models/account"
require "models/company"
require "models/toy"
require "models/matey"

SIGNED_ID_VERIFIER_TEST_SECRET = -> { "This is normally set by the railtie initializer when used with Rails!" }

ActiveRecord::Base.signed_id_verifier_secret = SIGNED_ID_VERIFIER_TEST_SECRET

class SignedIdTest < ActiveRecord::TestCase
  fixtures :accounts, :toys, :companies

  setup do
    @account = Account.first
    @toy = Toy.first
  end

  test "find signed record" do
    assert_equal @account, Account.find_signed(@account.signed_id)
  end

  test "find signed record with custom primary key" do
    assert_equal @toy, Toy.find_signed(@toy.signed_id)
  end

  test "find signed record for single table inheritance (STI Models)" do
    assert_equal Company.first, Company.find_signed(Company.first.signed_id)
  end

  test "raise UnknownPrimaryKey when model have no primary key" do
    error = assert_raises(ActiveRecord::UnknownPrimaryKey) do
      Matey.find_signed("this will not be even verified")
    end
    assert_equal "Unknown primary key for table mateys in model Matey.", error.message
  end

  test "find signed record with a bang" do
    assert_equal @account, Account.find_signed!(@account.signed_id)
  end

  test "fail to find record from broken signed id" do
    assert_nil Account.find_signed("this won't find anything")
  end

  test "find signed record within expiration date" do
    assert_equal @account, Account.find_signed(@account.signed_id(expires_in: 1.minute))
  end

  test "fail to find signed record within expiration date" do
    signed_id = @account.signed_id(expires_in: 1.minute)
    travel 2.minutes
    assert_nil Account.find_signed(signed_id)
  end

  test "fail to find record from that has since been destroyed" do
    signed_id = @account.signed_id(expires_in: 1.minute)
    @account.destroy
    assert_nil Account.find_signed signed_id
  end

  test "finding record from broken signed id raises on the bang" do
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      Account.find_signed! "this will blow up"
    end
  end

  test "finding signed record outside expiration date raises on the bang" do
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

  test "use a custom verifier" do
    old_verifier = Account.signed_id_verifier
    Account.signed_id_verifier = ActiveSupport::MessageVerifier.new("sekret")
    assert_not_equal ActiveRecord::Base.signed_id_verifier, Account.signed_id_verifier
    assert_equal @account, Account.find_signed(@account.signed_id)
  ensure
    Account.signed_id_verifier = old_verifier
  end
end
