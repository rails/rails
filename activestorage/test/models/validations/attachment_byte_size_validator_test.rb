# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::AttachmentByteSizeValidatorTest < ActiveSupport::TestCase
  VALIDATOR = ActiveStorage::Validations::AttachmentByteSizeValidator

  setup do
    @old_validators = User._validators.deep_dup
    @old_callbacks = User._validate_callbacks.deep_dup

    @blob = create_blob(filename: "funky.jpg")
    @user = User.create(name: "Anjali")

    @byte_size = @blob.byte_size

    @minimum = @byte_size - 1
    @maximum = @byte_size + 1
    @range = @minimum..@maximum

    @bad_minimum = 50.gigabytes
    @bad_maximum = 1.byte
    @bad_range = 50.gigabytes..51.gigabytes
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
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_range)

    assert @user.save
  end

  test "new record, creating attachments" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_range)

    @user = User.new(name: "Rohini")
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:avatar]
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, in: @range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @range)

    assert @user.save
  end

  test "persisted record, creating attachments" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_range)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:avatar]
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, in: @range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @range)

    assert @user.save
  end

  test "persisted record, updating attachments" do
    other_blob = create_blob(filename: "town.jpg")
    @user.avatar.attach(other_blob)
    @user.highlights.attach(other_blob)

    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_range)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:avatar]
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, in: @range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @range)

    assert @user.save
  end

  test "persisted record, updating some other field" do
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_with(VALIDATOR, attributes: :avatar, in: @range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @range)

    @user.name = "Rohini"

    assert @user.save
  end

  test "persisted record, destroying attachments" do
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_with(VALIDATOR, attributes: :avatar, in: @range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @range)

    @user.avatar.detach
    @user.highlights.detach

    assert @user.save
  end

  test "destroying record with attachments" do
    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    User.validates_with(VALIDATOR, attributes: :avatar, in: @range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @range)

    @user.avatar.detach
    @user.highlights.detach

    assert @user.destroy
    assert_not @user.persisted?
  end

  test "new record, with no attachment" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_range)

    @user = User.new(name: "Rohini")

    assert @user.save
  end

  test "persisted record, with no attachment" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_range)

    assert @user.save
  end

  test "destroying record, with no attachment" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_range)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_range)

    assert @user.destroy
    assert_not @user.persisted?
  end

  test "specifying :minimum option" do
    User.validates_with(VALIDATOR, attributes: :avatar, minimum: @bad_minimum)
    User.validates_with(VALIDATOR, attributes: :highlights, minimum: @bad_minimum)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["must be greater than or equal to 50 GB"], @user.errors.messages[:avatar]
    assert_equal ["must be greater than or equal to 50 GB"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, minimum: @minimum)
    User.validates_with(VALIDATOR, attributes: :highlights, minimum: @minimum)

    assert @user.save
  end

  test "specifying :maximum option" do
    User.validates_with(VALIDATOR, attributes: :avatar, maximum: @bad_maximum)
    User.validates_with(VALIDATOR, attributes: :highlights, maximum: @bad_maximum)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["must be less than or equal to 1 Byte"], @user.errors.messages[:avatar]
    assert_equal ["must be less than or equal to 1 Byte"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, maximum: @maximum)
    User.validates_with(VALIDATOR, attributes: :highlights, maximum: @maximum)

    assert @user.save
  end

  test "specifying both :minimum and :maximum options" do
    User.validates_with(VALIDATOR, attributes: :avatar, minimum: @bad_minimum, maximum: @bad_maximum)
    User.validates_with(VALIDATOR, attributes: :highlights, minimum: @bad_minimum, maximum: @bad_maximum)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    errors = ["must be greater than or equal to 50 GB",
      "must be less than or equal to 1 Byte"]
    assert_equal errors, @user.errors.messages[:avatar]
    assert_equal errors, @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_with(VALIDATOR, attributes: :avatar, minimum: @minimum, maximum: @maximum)
    User.validates_with(VALIDATOR, attributes: :highlights, minimum: @minimum, maximum: @maximum)

    assert @user.save
  end

  test "specifying no options" do
    exception = assert_raise(ArgumentError) do
      User.validates_with(VALIDATOR, attributes: :avatar)
    end

    assert_equal(
      "You must pass either :minimum, :maximum, or :in to the validator",
      exception.message
    )
  end

  test "specifying redundant options" do
    exception = assert_raise(ArgumentError) do
      User.validates_with(VALIDATOR, attributes: :avatar, in: @range, minimum: @minimum)
    end

    assert_equal(
      "Cannot pass :minimum or :maximum if already passing :in",
      exception.message
    )
  end

  test "validating with `validates()`" do
    User.validates(:avatar, attachment_byte_size: { in: @bad_range })
    User.validates(:highlights, attachment_byte_size: { in: @bad_range })

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:avatar]
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates(:avatar, attachment_byte_size: { in: @range })
    User.validates(:highlights, attachment_byte_size: { in: @range })

    assert @user.save
  end

  test "validating with `validates()`, Range shortcut option" do
    User.validates(:avatar, attachment_byte_size: @bad_range)
    User.validates(:highlights, attachment_byte_size: @bad_range)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:avatar]
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates(:avatar, attachment_byte_size: @range)
    User.validates(:highlights, attachment_byte_size: @range)

    assert @user.save
  end

  test "validating with `validates()`, invalid shortcut option" do
    exception = assert_raise(ArgumentError) do
      User.validates(:avatar, attachment_byte_size: "foo")
    end

    assert_equal(
      "You must pass either :minimum, :maximum, or :in to the validator",
      exception.message
    )
  end

  test "validating with `validates_attachment()`" do
    User.validates_attachment(:avatar, byte_size: { in: @bad_range })
    User.validates_attachment(:highlights, byte_size: { in: @bad_range })

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:avatar]
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_attachment(:avatar, byte_size: { in: @range })
    User.validates_attachment(:highlights, byte_size: { in: @range })

    assert @user.save
  end

  test "validating with `validates_attachment()`, Range shortcut option" do
    User.validates_attachment(:avatar, byte_size: @bad_range)
    User.validates_attachment(:highlights, byte_size: @bad_range)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:avatar]
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_attachment(:avatar, byte_size: @range)
    User.validates_attachment(:highlights, byte_size: @range)

    assert @user.save
  end

  test "validating with `validates_attachment()`, invalid shortcut option" do
    exception = assert_raise(ArgumentError) do
      User.validates_attachment(:avatar, byte_size: "foo")
    end

    assert_equal(
      "You must pass either :minimum, :maximum, or :in to the validator",
      exception.message
    )
  end

  test "validating with `validates_attachment_byte_size()`" do
    User.validates_attachment_byte_size(:avatar, in: @bad_range)
    User.validates_attachment_byte_size(:highlights, in: @bad_range)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:avatar]
    assert_equal ["must be between 50 GB and 51 GB"], @user.errors.messages[:highlights]

    User.clear_validators!

    User.validates_attachment_byte_size(:avatar, in: @range)
    User.validates_attachment_byte_size(:highlights, in: @range)

    assert @user.save
  end

  test "specifying a :message option" do
    message = "Validating %{model}#%{attribute}. The min is %{minimum} and "\
      "the max is %{maximum}"

    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_range, message: message)
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_range, message: message)

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert_not @user.valid?
    assert_equal(
      ["Validating User#Avatar. The min is 50 GB and the max is 51 GB"],
      @user.errors.messages[:avatar]
    )
    assert_equal(
      ["Validating User#Highlights. The min is 50 GB and the max is 51 GB"],
      @user.errors.messages[:highlights]
    )
  end

  test "inheritance of default ActiveModel options" do
    User.validates_with(VALIDATOR, attributes: :avatar, in: @bad_range, if: Proc.new { false })
    User.validates_with(VALIDATOR, attributes: :highlights, in: @bad_range, if: Proc.new { false })

    @user.avatar.attach(@blob)
    @user.highlights.attach(@blob)

    assert @user.save
  end
end
