# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AttachmentPresenceValidatorTest < ActiveSupport::TestCase
  VALIDATOR = ActiveStorage::Validations::AttachmentPresenceValidator

  setup do
    @old_validators = User._validators.deep_dup
    @old_callbacks = User._validate_callbacks.deep_dup

    @blob = create_blob(filename: "funky.jpg")
    @user = User.create(name: "Anjali")
  end

  teardown do
    User.destroy_all
    ActiveStorage::Blob.all.each(&:purge)

    User.clear_validators!
    # NOTE: `clear_validators!` clears both registered validators and any
    # callbacks registered by `validate()`, so ensure that both are restored
    User._validators = @old_validators if @old_validators
    User._validate_callbacks = @old_callbacks if @old_callbacks
  end

  test "record has no attachment" do
    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    assert_not @user.save
  end

  test "new record, creating attachments" do
    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    @user = User.new(name: "Rohini")
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert @user.save
  end

  test "persisted record, creating attachments" do
    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert @user.save
  end

  test "persisted record, updating attachments" do
    other_blob = create_blob(filename: "town.jpg")
    @user.avatar.attach(other_blob)
    @user.highlights.attach(other_blob)

    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert @user.valid?

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    assert @user.save
  end

  test "persisted record, updating some other field" do
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    @user.name = "Rohini"

    assert @user.save
  end

  test "persisted record, destroying attachments" do
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    @user.avatar.detach
    @user.highlights.detach

    assert_not @user.save
  end

  test "destroying record with attachments" do
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    @user.avatar.detach
    @user.highlights.detach

    assert @user.destroy
    assert_not @user.persisted?
  end

  test "new record, with no attachment" do
    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    @user = User.new(name: "Rohini")

    assert_not @user.save
  end

  test "persisted record, with no attachment" do
    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    assert_not @user.save
  end

  test "destroying record, with no attachment" do
    User.validates_with(VALIDATOR, attributes: :avatar)
    User.validates_with(VALIDATOR, attributes: :highlights)

    assert @user.destroy
    assert_not @user.persisted?
  end

  test "validating with `validates()`" do
    User.validates(:avatar, attachment_presence: true)
    User.validates(:highlights, attachment_presence: true)

    assert_not @user.valid?
    assert_equal ["can't be blank"], @user.errors.messages[:avatar]
    assert_equal ["can't be blank"], @user.errors.messages[:highlights]

    User.clear_validators!

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates(:avatar, attachment_presence: true)
    User.validates(:highlights, attachment_presence: true)

    assert @user.save
  end

  test "validating with `validates_attachment()`" do
    User.validates_attachment(:avatar, presence: true)
    User.validates_attachment(:highlights, presence: true)

    assert_not @user.valid?

    User.clear_validators!

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_attachment(:avatar, presence: true)
    User.validates_attachment(:highlights, presence: true)

    assert @user.save
  end

  test "validating with `validates_attachment_presence()`" do
    User.validates_attachment_presence(:avatar)
    User.validates_attachment_presence(:highlights)

    assert_not @user.valid?
    assert_equal ["can't be blank"], @user.errors.messages[:avatar]
    assert_equal ["can't be blank"], @user.errors.messages[:highlights]

    User.clear_validators!


    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_attachment_presence(:avatar)
    User.validates_attachment_presence(:highlights)

    assert @user.save
  end

  test "specifying a :message option" do
    message = "Validating %{model}#%{attribute}. The %{attribute} can't be blank"

    User.validates_with(VALIDATOR, attributes: :avatar, message: message)
    User.validates_with(VALIDATOR, attributes: :highlights, message: message)

    assert_not @user.valid?
    assert_equal(
      ["Validating User#Avatar. The Avatar can't be blank"],
      @user.errors.messages[:avatar]
    )
    assert_equal(
      ["Validating User#Highlights. The Highlights can't be blank"],
      @user.errors.messages[:highlights]
    )
  end

  test "inheritance of default ActiveModel options" do
    User.validates_with(VALIDATOR, attributes: :avatar, presence: true, if: Proc.new { false })
    User.validates_with(VALIDATOR, attributes: :highlights, presence: true, if: Proc.new { false })

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert @user.save
  end
end
