# frozen_string_literal: true

require "cases/helper"
require "models/account"
require "models/company"
require "models/toy"
require "models/matey"

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
    @original_message_verifiers = ActiveRecord.message_verifiers
    ActiveRecord.message_verifiers = ActiveSupport::MessageVerifiers.new { "secret" }.rotate_defaults

    @account = Account.first
    @toy = Toy.first
  end

  teardown do
    ActiveRecord.message_verifiers = @original_message_verifiers
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

  test "deprecation warning for setting signed_id_verifier_secret" do
    assert_deprecated(ActiveRecord.deprecator) do
      ActiveRecord::Base.signed_id_verifier_secret = "new secret"
    end
  ensure
    ActiveRecord.deprecator.silence do
      ActiveRecord::Base.signed_id_verifier_secret = nil
    end
  end

  test "fail to work when signed_id_verifier_secret lambda is nil" do
    @original_secret = ActiveRecord::Base.signed_id_verifier_secret

    ActiveRecord.deprecator.silence do
      ActiveRecord::Base.signed_id_verifier_secret = -> { nil }
    end

    assert_raises(ArgumentError) do
      model.signed_id
    end
  ensure
    ActiveRecord.deprecator.silence do
      ActiveRecord::Base.signed_id_verifier_secret = @original_secret
    end
  end

  test "signed_id_verifier is ActiveRecord.message_verifiers['active_record/signed_id'] by default" do
    assert_same ActiveRecord.message_verifiers["active_record/signed_id"], model_class.signed_id_verifier
  end

  test "signed_id raises when ActiveRecord.message_verifiers has not been set" do
    ActiveRecord.message_verifiers = nil

    assert_raises(match: /to use signed IDs/) do
      model.signed_id
    end
  end

  test "using custom signed_id_verifier" do
    model_class.signed_id_verifier = ActiveSupport::MessageVerifier.new("custom secret")
    assert_equal model, model_class.find_signed(model.signed_id)
  end

  test "signed_id_verifier behaves as class_attribute" do
    assert_same ActiveRecord::Base.signed_id_verifier, model_class.signed_id_verifier
    assert_same model_class.signed_id_verifier, model_subclass.signed_id_verifier

    model_class.signed_id_verifier = ActiveSupport::MessageVerifier.new("secret")

    assert_not_same ActiveRecord::Base.signed_id_verifier, model_class.signed_id_verifier
    assert_same model_class.signed_id_verifier, model_subclass.signed_id_verifier
  end

  test "when signed_id_verifier_secret is set, signed_id_verifier behaves as singleton instance variable" do
    ActiveRecord.deprecator.silence do
      model_class.signed_id_verifier_secret = "secret"
    end

    assert_no_changes -> { [ActiveRecord::Base.signed_id_verifier, model_subclass.signed_id_verifier] } do
      model_class.signed_id_verifier = ActiveSupport::MessageVerifier.new("secret")
    end
  end

  test "when signed_id_verifier_secret is set, signed_id_verifier uses legacy options by default" do
    ActiveRecord.deprecator.silence do
      model_class.signed_id_verifier_secret = "secret"
    end

    legacy_verifier = ActiveSupport::MessageVerifier.new("secret", digest: "SHA256", serializer: JSON, url_safe: true)

    assert_equal "message", legacy_verifier.verify(model_class.signed_id_verifier.generate("message"))
    assert_equal "message", model_class.signed_id_verifier.verify(legacy_verifier.generate("message"))
  end

  test "on_rotation callback using custom verifier" do
    model_class.signed_id_verifier = ActiveSupport::MessageVerifier.new("old secret")
    old_signed_id = model.signed_id

    on_rotation_is_called = false
    model_class.signed_id_verifier = ActiveSupport::MessageVerifier.new("new secret", on_rotation: -> { on_rotation_is_called = true })
    model_class.signed_id_verifier.rotate("old secret")

    model_class.find_signed(old_signed_id)
    assert on_rotation_is_called
  end

  test "on_rotation callback using find_signed & find_signed!" do
    model_class.signed_id_verifier = ActiveSupport::MessageVerifier.new("old secret")
    old_signed_id = model.signed_id

    model_class.signed_id_verifier = ActiveSupport::MessageVerifier.new("new secret")
    model_class.signed_id_verifier.rotate("old secret")

    on_rotation_is_called = false
    assert model_class.find_signed(old_signed_id, on_rotation: -> { on_rotation_is_called = true })
    assert on_rotation_is_called

    on_rotation_is_called = false
    assert model_class.find_signed!(old_signed_id, on_rotation: -> { on_rotation_is_called = true })
    assert on_rotation_is_called
  end

  test "cannot get a signed ID for a new record" do
    assert_raises ArgumentError, match: /Cannot get a signed_id for a new record/ do
      Account.new.signed_id
    end
  end

  test "can get a signed ID in an after_create" do
    assert_not_nil GetSignedIDInCallback.create.signed_id_from_callback
  end

  private
    def model_class
      @model_class ||= Class.new(Account)
    end

    def model_subclass
      @model_subclass ||= Class.new(model_class)
    end

    def model
      @model ||= model_class.first
    end
end
