# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AttachmentContentTypeValidatorTest < ActiveSupport::TestCase
  VALIDATOR = ActiveStorage::Validations::AttachmentContentTypeValidator

  setup do
    @old_validators = User._validators.deep_dup
    @old_callbacks = User._validate_callbacks.deep_dup

    @blob = create_blob(filename: "funky.jpg")
    @user = User.create(name: "Anjali")

    @content_types = %w[text/plain image/jpeg]
    @bad_content_types = %w[audio/ogg application/pdf]
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
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_content_types)

    assert @user.save
  end

  test "new record, creating attachments" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_content_types)

    @user = User.new(name: "Rohini")
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, in: @content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @content_types)

    assert @user.save
  end

  test "persisted record, creating attachments" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_content_types)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, in: @content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @content_types)

    assert @user.save
  end

  test "persisted record, updating attachments" do
    old_blob = create_blob(filename: "town.jpg")
    @user.avatar.attach(old_blob)
    @user.highlights.attach(old_blob)

    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_content_types)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, in: @content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @content_types)

    assert @user.save
  end

  test "persisted record, updating some other field" do
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_with(VALIDATOR, attributes: :avatar, in: @content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @content_types)

    @user.name = "Rohini"

    assert @user.save
  end

  test "persisted record, destroying attachments" do
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_with(VALIDATOR, attributes: :avatar, in: @content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @content_types)

    @user.avatar.detach
    @user.highlights.detach

    assert @user.save
  end

  test "destroying record with attachments" do
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_with(VALIDATOR, attributes: :avatar, in: @content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @content_types)

    @user.avatar.detach
    @user.highlights.detach

    assert @user.destroy
    assert_not @user.persisted?
  end

  test "new record, with no attachment" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_content_types)

    @user = User.new(name: "Rohini")

    assert @user.save
  end

  test "persisted record, with no attachment" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_content_types)

    assert @user.save
  end

  test "destroying record, with no attachment" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_content_types)

    assert @user.destroy
    assert_not @user.persisted?
  end

  test "specifying :in option as String" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_content_types.first)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_content_types.first)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, in: @content_types.first)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @content_types.first)

    assert @user.save
  end

  test "specifying :not option" do
    User.validates_with(VALIDATOR, attributes: :avatar, not: @content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, not: @content_types)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is reserved"], @user.errors.messages[:avatar]
    assert_equal ["is reserved"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, not: @bad_content_types)
    User.validates_with(VALIDATOR, attributes: :highlights, not: @bad_content_types)

    assert @user.save
  end

  test "specifying :not option as a String" do
    User.validates_with(VALIDATOR, attributes: :avatar, not: @content_types.first)
    User.validates_with(VALIDATOR, attributes: :highlights, not: @content_types.first)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is reserved"], @user.errors.messages[:avatar]
    assert_equal ["is reserved"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, not: @bad_content_types.first)
    User.validates_with(VALIDATOR, attributes: :highlights, not: @bad_content_types.first)

    assert @user.save
  end

  test "specifying no options" do
    exception = assert_raise(ArgumentError) do
      User.validates_with(VALIDATOR, attributes: :avatar)
    end

    assert_equal(
      "You must pass at least one of in, not, with to the validator",
      exception.message
    )
  end

  test "specifying redundant options" do
    exception = assert_raise(ArgumentError) do
      User.validates_with(VALIDATOR, attributes: :avatar, in: @content_types, not: @bad_content_types)
    end

    assert_equal("Cannot pass both :in and :not", exception.message)
  end

  test "validating with `validates()`" do
    User.validates(:avatar, attachment_content_type: { in: @bad_content_types })
    User.validates(:highlights, attachment_content_type: { in: @bad_content_types })

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates(:avatar, attachment_content_type: { in: @content_types })
    User.validates(:highlights, attachment_content_type: { in: @content_types })

    assert @user.save
  end

  test "validating with `validates()`, String shortcut option" do
    User.validates(:avatar, attachment_content_type: @bad_content_types.first)
    User.validates(:highlights, attachment_content_type: @bad_content_types.first)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates(:avatar, attachment_content_type: @content_types.first)
    User.validates(:highlights, attachment_content_type: @content_types.first)

    assert @user.save
  end

  test "validating with `validates()`, Array shortcut option" do
    User.validates(:avatar, attachment_content_type: @bad_content_types)
    User.validates(:highlights, attachment_content_type: @bad_content_types)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates(:avatar, attachment_content_type: @content_types)
    User.validates(:highlights, attachment_content_type: @content_types)

    assert @user.save
  end

  test "validating with `validates()`, invalid shortcut option" do
    User.validates(:avatar, attachment_content_type: @bad_content_types.first.to_sym)
    User.validates(:highlights, attachment_content_type: @bad_content_types.first.to_sym)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates(:avatar, attachment_content_type: @content_types.first.to_sym)
    User.validates(:highlights, attachment_content_type: @content_types.first.to_sym)

    assert @user.save
  end

  test "validating with `validates_attachment()`" do
    User.validates_attachment(:avatar, content_type: { in: @bad_content_types })
    User.validates_attachment(:highlights, content_type: { in: @bad_content_types })

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_attachment(:avatar, content_type: { in: @content_types })
    User.validates_attachment(:highlights, content_type: { in: @content_types })

    assert @user.save
  end

  test "validating with `validates_attachment()`, String shortcut option" do
    User.validates_attachment(:avatar, content_type: @bad_content_types.first)
    User.validates_attachment(:highlights, content_type: @bad_content_types.first)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_attachment(:avatar, content_type: @content_types.first)
    User.validates_attachment(:highlights, content_type: @content_types.first)

    assert @user.save
  end

  test "validating with `validates_attachment()`, Array shortcut option" do
    User.validates_attachment(:avatar, content_type: @bad_content_types)
    User.validates_attachment(:highlights, content_type: @bad_content_types)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_attachment(:avatar, content_type: @content_types)
    User.validates_attachment(:highlights, content_type: @content_types)

    assert @user.save
  end

  test "validating with `validates_attachment()`, Symbol shortcut option" do
    User.validates_attachment(:avatar, content_type: @bad_content_types.first.to_sym)
    User.validates_attachment(:highlights, content_type: @bad_content_types.first.to_sym)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_attachment(:avatar, content_type: @content_types.first.to_sym)
    User.validates_attachment(:highlights, content_type: @content_types.first.to_sym)

    assert @user.save
  end

  test "validating with `validates_attachment_content_type()`" do
    User.validates_attachment_content_type(:avatar, in: @bad_content_types)
    User.validates_attachment_content_type(:highlights, in: @bad_content_types)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["is not included in the list"], @user.errors.messages[:avatar]
    assert_equal ["is not included in the list"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_attachment_content_type(:avatar, in: @content_types)
    User.validates_attachment_content_type(:highlights, in: @content_types)

    assert @user.save
  end

  test "specifying a :message option" do
    message = "Content Type not valid for %{model}#%{attribute}"

    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_content_types, message: message)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_content_types, message: message)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal(
      ["Content Type not valid for User#Avatar"],
      @user.errors.messages[:avatar]
    )
    assert_equal(
      ["Content Type not valid for User#Highlights"],
      @user.errors.messages[:highlights]
    )
  end

  test "inheritance of default ActiveModel options" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_content_types, if: Proc.new { false })
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_content_types, if: Proc.new { false })

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert @user.save
  end
end
