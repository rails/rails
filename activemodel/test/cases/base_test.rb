# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  class ApplicationModel < Base
  end

  class Session < ApplicationModel
    attr_accessor :email, :password

    validates :email, presence: true,
      comparison: { on: :admin, equal_to: "admin@example.com" }
    validates :password, presence: true,
      comparison: { on: :admin, equal_to: "adminpassword" }

    def save!
      assign_attributes email: email.downcase
    end
  end

  class ConfirmationSession < Session
    attr_accessor :password_confirmation

    validates :password_confirmation, presence: true, comparison: { equal_to: :password }

    def save!
      super
    end
  end

  class PasswordlessSession < ApplicationModel
    attr_accessor :session

    validates :email, presence: true

    delegate_missing_to :session

    def save!
      assign_attributes password: ""
      session.save!(validate: false)
    end
  end

  class User
    attr_accessor :saved

    def save!
      self.saved = true
    end

    def persisted?
      saved
    end
  end

  class Profile < ApplicationModel
    attr_accessor :user

    delegate :save!, :persisted?, to: :user

    delegate_missing_to :user
  end

  class Base::ClassMethodsTest < ActiveModel::TestCase
    test ".validation_exceptions includes ValidationError" do
      assert_respond_to Session, :validation_exceptions
      assert_respond_to Session, :validation_exceptions=
      assert_includes Session.validation_exceptions, ValidationError
    end

    test ".validation_exceptions does not expose instance accessors" do
      session = Session.new

      assert_not_respond_to session, :validation_exceptions
      assert_not_respond_to session, :validation_exceptions=
    end

    test ".build without attributes" do
      session = Session.build

      assert_not_predicate session, :persisted?
      assert_nil session.email
      assert_nil session.password
    end

    test ".build with attributes" do
      attributes = { email: "email@example.com", password: "secret" }
      session = Session.build attributes

      assert_not_predicate session, :persisted?
      assert_equal "email@example.com", session.email
      assert_equal "secret", session.password
    end

    test ".build with an array of attributes" do
      attributes = [
        { email: "a@example.com", password: "secret" },
        { email: "b@example.com", password: "secret" }
      ]
      a, b = Session.build attributes

      assert_not_predicate a, :persisted?
      assert_equal "a@example.com", a.email
      assert_equal "secret", a.password
      assert_not_predicate b, :persisted?
      assert_equal "b@example.com", b.email
      assert_equal "secret", b.password
    end

    test ".build with a block" do
      attributes = { email: "email@example.com", password: "secret" }
      session = Session.build { |model| model.assign_attributes attributes }

      assert_not_predicate session, :persisted?
      assert_equal "email@example.com", session.email
      assert_equal "secret", session.password
    end

    test ".build with attributes and a block" do
      attributes = { email: "email@example.com" }
      session = Session.build(attributes) { |model| model.password = "secret" }

      assert_not_predicate session, :persisted?
      assert_equal "email@example.com", session.email
      assert_equal "secret", session.password
    end

    test ".build with an array of attributes and a block" do
      attributes = [{ email: "a@example.com" }, { email: "b@example.com" }]
      a, b = Session.build(attributes) { |model| model.password = "secret" }

      assert_not_predicate a, :persisted?
      assert_equal "a@example.com", a.email
      assert_equal "secret", a.password
      assert_not_predicate b, :persisted?
      assert_equal "b@example.com", b.email
      assert_equal "secret", b.password
    end

    test ".create! succeeds with attributes" do
      attributes = { email: "EMAIL@EXAMPLE.COM", password: "secret" }
      session = Session.create! attributes

      assert_predicate session, :persisted?
      assert_equal "email@example.com", session.email
      assert_equal "secret", session.password
    end

    test ".create! succeeds with an array of attributes" do
      attributes = [
        { email: "A@EXAMPLE.COM", password: "secret" },
        { email: "B@EXAMPLE.COM", password: "secret" }
      ]
      a, b = Session.create! attributes

      assert_predicate a, :persisted?
      assert_equal "a@example.com", a.email
      assert_equal "secret", a.password
      assert_predicate b, :persisted?
      assert_equal "b@example.com", b.email
      assert_equal "secret", b.password
    end

    test ".create! succeeds with a block" do
      attributes = { email: "EMAIL@EXAMPLE.COM", password: "secret" }
      session = Session.create! { |model| model.assign_attributes attributes }

      assert_predicate session, :persisted?
      assert_equal "email@example.com", session.email
      assert_equal "secret", session.password
    end

    test ".create! succeeds with attributes and a block" do
      attributes = { email: "EMAIL@EXAMPLE.COM" }
      session = Session.create!(attributes) { |model| model.password = "secret" }

      assert_predicate session, :persisted?
      assert_equal "email@example.com", session.email
      assert_equal "secret", session.password
    end

    test ".create! succeeds with an array of attributes and a block" do
      attributes = [{ email: "A@EXAMPLE.COM" }, { email: "b@example.com" }]
      a, b = Session.create!(attributes) { |model| model.password = "secret" }

      assert_predicate a, :persisted?
      assert_equal "a@example.com", a.email
      assert_equal "secret", a.password
      assert_predicate b, :persisted?
      assert_equal "b@example.com", b.email
      assert_equal "secret", b.password
    end

    test ".create! fails with attributes" do
      attributes = { email: "" }

      assert_raises ValidationError, match: "Validation failed: Email can't be blank, Password can't be blank" do
        Session.create! attributes
      end
    end

    test ".create! fails with an array of attributes" do
      attributes = [{ email: "" }, { email: "" }]

      assert_raises ValidationError, match: "Validation failed: Email can't be blank" do
        Session.create! attributes
      end
    end

    test ".create! fails with a block" do
      attributes = { email: "" }

      assert_raises ValidationError, match: "Validation failed: Email can't be blank, Password can't be blank" do
        Session.create! { |model| model.assign_attributes attributes }
      end
    end

    test ".create! fails with attributes and a block" do
      attributes = { email: "" }

      assert_raises ValidationError, match: "Validation failed: Email can't be blank" do
        Session.create!(attributes) { |model| model.password = "secret" }
      end
    end

    test ".create! fails with an array of attributes and a block" do
      attributes = [{ email: "" }, { email: "" }]

      assert_raises ValidationError, match: "Validation failed: Email can't be blank" do
        Session.create!(attributes) { |model| model.password = "secret" }
      end
    end

    test ".create succeeds with attributes" do
      attributes = { email: "EMAIL@EXAMPLE.COM", password: "secret" }
      session = Session.create attributes

      assert_predicate session, :persisted?
      assert_equal "email@example.com", session.email
      assert_equal "secret", session.password
    end

    test ".create succeeds with an array of attributes" do
      attributes = [
        { email: "A@EXAMPLE.COM", password: "secret" },
        { email: "B@EXAMPLE.COM", password: "secret" }
      ]
      a, b = Session.create attributes

      assert_predicate a, :persisted?
      assert_equal "a@example.com", a.email
      assert_equal "secret", a.password
      assert_predicate b, :persisted?
      assert_equal "b@example.com", b.email
      assert_equal "secret", b.password
    end

    test ".create succeeds with a block" do
      attributes = { email: "EMAIL@EXAMPLE.COM", password: "secret" }
      session = Session.create { |model| model.assign_attributes attributes }

      assert_predicate session, :persisted?
      assert_equal "email@example.com", session.email
      assert_equal "secret", session.password
    end

    test ".create succeeds with attributes and a block" do
      attributes = { email: "EMAIL@EXAMPLE.COM" }
      session = Session.create(attributes) { |model| model.password = "secret" }

      assert_predicate session, :persisted?
      assert_equal "email@example.com", session.email
      assert_equal "secret", session.password
    end

    test ".create succeeds with an array of attributes and a block" do
      attributes = [{ email: "A@EXAMPLE.COM" }, { email: "B@EXAMPLE.COM" }]
      a, b = Session.create(attributes) { |model| model.password = "secret" }

      assert_predicate a, :persisted?
      assert_equal "a@example.com", a.email
      assert_equal "secret", a.password
      assert_predicate b, :persisted?
      assert_equal "b@example.com", b.email
      assert_equal "secret", b.password
    end

    test ".create fails with attributes" do
      attributes = { email: "" }

      session = Session.create attributes

      assert_not_predicate session, :persisted?
      assert_not_empty session.errors[:email]
    end

    test ".create fails with an array of attributes" do
      attributes = [{ email: "" }, { email: "" }]

      a, b = Session.create attributes

      assert_not_predicate a, :persisted?
      assert_not_predicate b, :persisted?
      assert_not_empty a.errors[:email]
      assert_not_empty b.errors[:email]
    end

    test ".create fails with a block" do
      attributes = { email: "" }

      session = Session.create { |model| model.assign_attributes attributes }

      assert_not_predicate session, :persisted?
      assert_not_empty session.errors[:email]
    end

    test ".create fails with attributes and a block" do
      attributes = { email: "" }

      session = Session.create(attributes) { |model| model.password = "secret" }

      assert_not_predicate session, :persisted?
      assert_not_empty session.errors[:email]
    end

    test ".create fails with an array of attributes and a block" do
      attributes = [{ email: "" }, { email: "" }]

      a, b = Session.create(attributes) { |model| model.password = "secret" }

      assert_not_predicate a, :persisted?
      assert_not_predicate b, :persisted?
      assert_not_empty a.errors[:email]
      assert_not_empty b.errors[:email]
    end
  end

  class BaseTest < ActiveModel::TestCase
    test "#save! without an override no-ops" do
      subclass = Class.new(Base) do
        class_attribute :model_name, default: Name.new(self, nil, "ModelWithoutSave")
      end
      model = subclass.new

      assert_equal true, model.save!
      assert_predicate model, :persisted?
      assert_empty model.errors
    end

    test "#save! without an override runs validations" do
      subclass = Class.new(Base) do
        class_attribute :model_name, default: Name.new(self, nil, "ValidatedModelWithoutSave")

        attr_accessor :value

        validates :value, presence: true
      end
      model = subclass.new

      assert_raises ValidationError, match: "Validation failed: Value can't be blank" do
        model.save!
      end
      assert_not_predicate model, :persisted?
      assert_not_empty model.errors[:value]
    end

    test "#save! succeeds" do
      session = Session.new email: "a@example.com", password: "secret"

      saved = session.save!

      assert_equal true, saved
      assert_predicate session, :persisted?
      assert_empty session.errors
    end

    test "#save! succeeds when delegating missing methods" do
      session = Session.new email: "A@EXAMPLE.COM", password: "secret"
      passwordless_session = PasswordlessSession.new session: session

      saved = passwordless_session.save!

      assert_equal true, saved
      assert_equal "a@example.com", passwordless_session.email
      assert_equal "", passwordless_session.password
      assert_predicate passwordless_session, :persisted?
      assert_empty passwordless_session.errors
    end

    test "#save! succeeds when delegating #save!" do
      user = User.new
      profile = Profile.new(user: user)

      saved = profile.save!

      assert_equal true, saved
      assert_equal true, profile.saved
      assert_equal true, user.saved
      assert_predicate profile, :persisted?
      assert_predicate user, :persisted?
    end

    test "#save! succeeds when calling super from #save!" do
      session = ConfirmationSession.new(email: "USER@EXAMPLE.COM", password: "secret", password_confirmation: "secret")

      saved = session.save!

      assert_equal true, saved
      assert_predicate session, :persisted?
      assert_equal "user@example.com", session.email
      assert_equal "secret", session.password
      assert_equal "secret", session.password_confirmation
    end

    test "#save! with validate: false skips validations" do
      session = Session.new email: "", password: ""

      saved = session.save!(validate: false)

      assert_equal true, saved
      assert_predicate session, :persisted?
      assert_empty session.errors
    end

    test "#save! with context: forwards to validations" do
      session = Session.new email: "a@example.com", password: "secret"
      admin_session = Session.new email: "admin@example.com", password: "adminpassword"

      assert_raises ValidationError do
        session.save! context: :admin
      end
      assert_not_predicate session, :persisted?
      assert_not_empty session.errors[:password]

      saved = admin_session.save! context: :admin

      assert_equal true, saved
      assert_empty admin_session.errors
    end

    test "#save! fails" do
      session = Session.new

      assert_raises ValidationError do
        session.save!
      end
      assert_not_predicate session, :persisted?
      assert_not_empty session.errors[:email]
      assert_not_empty session.errors[:password]
    end

    test "#save! fails when delegating missing methods" do
      session = Session.new email: "", password: "secret"
      passwordless_session = PasswordlessSession.new session: session

      assert_raises ValidationError, match: "Validation failed: Email can't be blank" do
        passwordless_session.save!
      end
      assert_not_predicate passwordless_session, :persisted?
      assert_not_empty passwordless_session.errors[:email]
    end

    test "#save succeeds" do
      session = Session.new email: "a@example.com", password: "secret"

      saved = session.save

      assert_equal true, saved
      assert_predicate session, :persisted?
      assert_empty session.errors
    end

    test "#save fails" do
      session = Session.new

      saved = session.save
      assert_equal false, saved
      assert_not_predicate session, :persisted?
      assert_not_empty session.errors[:email]
      assert_not_empty session.errors[:password]
    end

    test "#update! succeeds" do
      session = Session.new

      updated = session.update! email: "A@EXAMPLE.COM", password: "secret"

      assert_equal true, updated
      assert_equal "a@example.com", session.email
      assert_equal "secret", session.password
      assert_predicate session, :persisted?
      assert_empty session.errors
    end

    test "#update! succeeds when delegating missing methods" do
      session = Session.new email: "A@EXAMPLE.COM", password: "secret"
      passwordless_session = PasswordlessSession.new

      saved = passwordless_session.update! session: session

      assert_equal true, saved
      assert_equal "a@example.com", passwordless_session.email
      assert_equal "", passwordless_session.password
      assert_predicate passwordless_session, :persisted?
      assert_empty passwordless_session.errors
    end

    test "#update! fails" do
      session = Session.new

      assert_raises ValidationError do
        session.update! email: "", password: ""
      end
      assert_equal "", session.email
      assert_equal "", session.password
      assert_not_predicate session, :persisted?
      assert_not_empty session.errors[:email]
      assert_not_empty session.errors[:password]
    end

    test "#update! fails when delegating missing methods" do
      session = Session.new email: "", password: "secret"
      passwordless_session = PasswordlessSession.new

      assert_raises ValidationError, match: "Validation failed: Email can't be blank" do
        passwordless_session.update! session: session
      end
      assert_not_predicate passwordless_session, :persisted?
      assert_not_empty passwordless_session.errors[:email]
    end

    test "#update succeeds" do
      session = Session.new

      updated = session.update email: "A@EXAMPLE.COM", password: "secret"

      assert_equal true, updated
      assert_equal "a@example.com", session.email
      assert_equal "secret", session.password
      assert_predicate session, :persisted?
      assert_empty session.errors
    end

    test "#update fails" do
      session = Session.new

      updated = session.update email: "", password: ""

      assert_equal false, updated
      assert_equal "", session.email
      assert_equal "", session.password
      assert_not_predicate session, :persisted?
      assert_not_empty session.errors[:email]
      assert_not_empty session.errors[:password]
    end

    test "#persisted? returns false for new instances" do
      session = Session.new

      assert_not_predicate session, :persisted?
      assert_predicate session, :new_model?
      assert_predicate session, :new_record?
    end

    test "#persisted? returns false when an instance fails to save" do
      session = Session.create

      assert_not_predicate session, :persisted?
      assert_predicate session, :new_model?
      assert_predicate session, :new_record?
    end

    test "#persisted? returns true when an instance successfully saves" do
      session = Session.create! email: "a@example.com", password: "secret"

      assert_predicate session, :persisted?
      assert_not_predicate session, :new_model?
      assert_not_predicate session, :new_record?
    end
  end

  class Base::CallbacksTest < ActiveModel::TestCase
    test "fires after_initialize callback" do
      model = build_model do
        attr_accessor :after_initialized_fired

        after_initialize { self.after_initialized_fired = true }
      end

      assert_equal true, model.after_initialized_fired
    end

    test "fires before_validation callback" do
      model = build_model do
        attr_accessor :before_validation_fired

        before_validation { self.before_validation_fired = true }
      end

      model.validate!

      assert_equal true, model.before_validation_fired
    end

    test "fires after_validation callback" do
      model = build_model do
        attr_accessor :after_validation_fired

        after_validation { self.after_validation_fired = true }
      end

      model.validate!

      assert_equal true, model.after_validation_fired
    end

    test "fires before_save callback" do
      model = build_model do
        attr_accessor :before_save_fired

        before_save { self.before_save_fired = true }
      end

      model.save!

      assert_equal true, model.before_save_fired
    end

    test "fires after_save callback" do
      model = build_model do
        attr_accessor :after_save_fired

        after_save { self.after_save_fired = true }
      end

      model.save!

      assert_equal true, model.after_save_fired
    end

    def build_model(&block)
      Class.new(Base, &block).new
    end
  end
end
