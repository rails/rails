## Rails 6.0.0 (August 16, 2019) ##

*   No changes.


## Rails 6.0.0.rc2 (July 22, 2019) ##

*   No changes.


## Rails 6.0.0.rc1 (April 24, 2019) ##

*   Type cast falsy boolean symbols on boolean attribute as false.

    Fixes #35676.

    *Ryuta Kamizono*

*   Change how validation error translation strings are fetched: The new behavior
    will first try the more specific keys, including doing locale fallback, then try
    the less specific ones.

    For example, this is the order in which keys will now be tried for a `blank`
    error on a `product`'s `title` attribute with current locale set to `en-US`:

        en-US.activerecord.errors.models.product.attributes.title.blank
        en-US.activerecord.errors.models.product.blank
        en-US.activerecord.errors.messages.blank

        en.activerecord.errors.models.product.attributes.title.blank
        en.activerecord.errors.models.product.blank
        en.activerecord.errors.messages.blank

        en-US.errors.attributes.title.blank
        en-US.errors.messages.blank

        en.errors.attributes.title.blank
        en.errors.messages.blank

    *Hugo Vacher*


## Rails 6.0.0.beta3 (March 11, 2019) ##

*   No changes.


## Rails 6.0.0.beta2 (February 25, 2019) ##

*   Fix date value when casting a multiparameter date hash to not convert
    from Gregorian date to Julian date.

    Before:

        Day.new({"day(1i)"=>"1", "day(2i)"=>"1", "day(3i)"=>"1"})
        # => #<Day id: nil, day: "0001-01-03", created_at: nil, updated_at: nil>

    After:

        Day.new({"day(1i)"=>"1", "day(2i)"=>"1", "day(3i)"=>"1"})
        # => #<Day id: nil, day: "0001-01-01", created_at: nil, updated_at: nil>

    Fixes #28521.

    *Sayan Chakraborty*

*   Fix year value when casting a multiparameter time hash.

    When assigning a hash to a time attribute that's missing a year component
    (e.g. a `time_select` with `:ignore_date` set to `true`) then the year
    defaults to 1970 instead of the expected 2000. This results in the attribute
    changing as a result of the save.

    Before:
    ```
    event = Event.new(start_time: { 4 => 20, 5 => 30 })
    event.start_time # => 1970-01-01 20:30:00 UTC
    event.save
    event.reload
    event.start_time # => 2000-01-01 20:30:00 UTC
    ```

    After:
    ```
    event = Event.new(start_time: { 4 => 20, 5 => 30 })
    event.start_time # => 2000-01-01 20:30:00 UTC
    event.save
    event.reload
    event.start_time # => 2000-01-01 20:30:00 UTC
    ```

    *Andrew White*


## Rails 6.0.0.beta1 (January 18, 2019) ##

*   Internal calls to `human_attribute_name` on an `Active Model` now pass attributes as strings instead of symbols
    in some cases.

    This is in line with examples in Rails docs and puts the code in line with the intention -
    the potential use of strings or symbols.

    It is recommended to cast the attribute input to your desired type as if you you are overriding that methid.

    *Martin Larochelle*

*   Add `ActiveModel::Errors#of_kind?`.

    *bogdanvlviv*, *Rafael Mendonça França*

*   Fix numericality equality validation of `BigDecimal` and `Float`
    by casting to `BigDecimal` on both ends of the validation.

    *Gannon McGibbon*

*   Add `#slice!` method to `ActiveModel::Errors`.

    *Daniel López Prat*

*   Fix numericality validator to still use value before type cast except Active Record.

    Fixes #33651, #33686.

    *Ryuta Kamizono*

*   Fix `ActiveModel::Serializers::JSON#as_json` method for timestamps.

    Before:
    ```
    contact = Contact.new(created_at: Time.utc(2006, 8, 1))
    contact.as_json["created_at"] # => 2006-08-01 00:00:00 UTC
    ```

    After:
    ```
    contact = Contact.new(created_at: Time.utc(2006, 8, 1))
    contact.as_json["created_at"] # => "2006-08-01T00:00:00.000Z"
    ```

    *Bogdan Gusiev*

*   Allows configurable attribute name for `#has_secure_password`. This
    still defaults to an attribute named 'password', causing no breaking
    change. There is a new method `#authenticate_XXX` where XXX is the
    configured attribute name, making the existing `#authenticate` now an
    alias for this when the attribute is the default 'password'.

    Example:

        class User < ActiveRecord::Base
          has_secure_password :recovery_password, validations: false
        end

        user = User.new()
        user.recovery_password = "42password"
        user.recovery_password_digest # => "$2a$04$iOfhwahFymCs5weB3BNH/uX..."
        user.authenticate_recovery_password('42password') # => user

    *Unathi Chonco*

*   Add `config.active_model.i18n_customize_full_message` in order to control whether
    the `full_message` error format can be overridden at the attribute or model
    level in the locale files. This is `false` by default.

    *Martin Larochelle*

*   Rails 6 requires Ruby 2.5.0 or newer.

    *Jeremy Daer*, *Kasper Timm Hansen*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/activemodel/CHANGELOG.md) for previous changes.
