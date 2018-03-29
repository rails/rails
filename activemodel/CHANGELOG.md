## Rails 5.0.7 (March 29, 2018) ##

*   No changes.


## Rails 5.0.6 (September 07, 2017) ##

*   No changes.


## Rails 5.0.6.rc1 (August 24, 2017) ##

*   No changes.


## Rails 5.0.5 (July 31, 2017) ##

*   No changes.


## Rails 5.0.5.rc2 (July 25, 2017) ##

*   No changes.


## Rails 5.0.5.rc1 (July 19, 2017) ##

*   No changes.


## Rails 5.0.4 (June 19, 2017) ##

*   Fix regression in numericality validator when comparing Decimal and Float input 
    values with more scale than the schema.

    *Bradley Priest*


## Rails 5.0.3 (May 12, 2017) ##

*   The original string assigned to a model attribute is no longer incorrectly
    frozen.

    Fixes #24185, #28718.

    *Matthew Draper*

*   Avoid converting integer as a string into float.

    *namusyaka*


## Rails 5.0.2 (March 01, 2017) ##

*   No changes.


## Rails 5.0.1 (December 21, 2016) ##

*   No changes.


## Rails 5.0.1.rc2 (December 10, 2016) ##

*   No changes.


## Rails 5.0.1.rc1 (December 01, 2016) ##

*   Fix `Type::Date#serialize` to cast a value to a date object properly.
    This casting fixes queries for finding records by date column.

    Fixes #25354.

    *Ryuta Kamizono*


## Rails 5.0.0 (June 30, 2016) ##

*   `Dirty`'s `*_changed?` methods now return an actual singleton, never `nil`, as in 4.2.
    Fixes #24220.

    *Sen-Zhang*

*   Ensure that instances of `ActiveModel::Errors` can be marshalled.
    Fixes #25165.

    *Sean Griffin*

*   Allow passing record being validated to the message proc to generate
    customized error messages for that object using I18n helper.

    *Prathamesh Sonpatki*

*   Validate multiple contexts on `valid?` and `invalid?` at once.

    Example:

        class Person
          include ActiveModel::Validations

          attr_reader :name, :title
          validates_presence_of :name, on: :create
          validates_presence_of :title, on: :update
        end

        person = Person.new
        person.valid?([:create, :update])    # => false
        person.errors.messages               # => {:name=>["can't be blank"], :title=>["can't be blank"]}

    *Dmitry Polushkin*

*   Add case_sensitive option for confirmation validator in models.

    *Akshat Sharma*

*   Ensure `method_missing` is called for methods passed to
    `ActiveModel::Serialization#serializable_hash` that don't exist.

    *Jay Elaraj*

*   Remove `ActiveModel::Serializers::Xml` from core.

    *Zachary Scott*

*   Add `ActiveModel::Dirty#[attr_name]_previously_changed?` and
    `ActiveModel::Dirty#[attr_name]_previous_change` to improve access
    to recorded changes after the model has been saved.

    It makes the dirty-attributes query methods consistent before and after
    saving.

    *Fernando Tapia Rico*

*   Deprecate the `:tokenizer` option for `validates_length_of`, in favor of
    plain Ruby.

    *Sean Griffin*

*   Deprecate `ActiveModel::Errors#add_on_empty` and `ActiveModel::Errors#add_on_blank`
    with no replacement.

    *Wojciech Wnętrzak*

*   Deprecate `ActiveModel::Errors#get`, `ActiveModel::Errors#set` and
    `ActiveModel::Errors#[]=` methods that have inconsistent behavior.

    *Wojciech Wnętrzak*

*   Allow symbol as values for `tokenize` of `LengthValidator`.

    *Kensuke Naito*

*   Assigning an unknown attribute key to an `ActiveModel` instance during initialization
    will now raise `ActiveModel::AttributeAssignment::UnknownAttributeError` instead of
    `NoMethodError`.

    Example:

        User.new(foo: 'some value')
        # => ActiveModel::AttributeAssignment::UnknownAttributeError: unknown attribute 'foo' for User.

    *Eugene Gilburg*

*   Extracted `ActiveRecord::AttributeAssignment` to `ActiveModel::AttributeAssignment`
    allowing to use it for any object as an includable module.

    Example:

        class Cat
          include ActiveModel::AttributeAssignment
          attr_accessor :name, :status
        end

        cat = Cat.new
        cat.assign_attributes(name: "Gorby", status: "yawning")
        cat.name   # => 'Gorby'
        cat.status # => 'yawning'
        cat.assign_attributes(status: "sleeping")
        cat.name   # => 'Gorby'
        cat.status # => 'sleeping'

    *Bogdan Gusiev*

*   Add `ActiveModel::Errors#details`

    To be able to return type of used validator, one can now call `details`
    on errors instance.

    Example:

        class User < ActiveRecord::Base
          validates :name, presence: true
        end

        user = User.new; user.valid?; user.errors.details
        => {name: [{error: :blank}]}

    *Wojciech Wnętrzak*

*   Change `validates_acceptance_of` to accept `true` by default besides `'1'`.

    The default for `validates_acceptance_of` is now `'1'` and `true`.
    In the past, only `"1"` was the default and you were required to pass
    `accept: true` separately.

    *mokhan*

*   Remove deprecated `ActiveModel::Dirty#reset_#{attribute}` and
    `ActiveModel::Dirty#reset_changes`.

    *Rafael Mendonça França*

*   Change the way in which callback chains can be halted.

    The preferred method to halt a callback chain from now on is to explicitly
    `throw(:abort)`.
    In the past, returning `false` in an Active Model `before_` callback had
    the side effect of halting the callback chain.
    This is not recommended anymore and, depending on the value of the
    `ActiveSupport.halt_callback_chains_on_return_false` option, will
    either not work at all or display a deprecation warning.

    *claudiob*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/activemodel/CHANGELOG.md) for previous changes.
