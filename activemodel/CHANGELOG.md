## Rails 4.0.5 (May 6, 2014) ##

*No changes*


## Rails 4.0.4 (March 14, 2014) ##

*   `#to_param` returns `nil` if `#to_key` returns `nil`. Fixes #11399.

    *Yves Senn*


## Rails 4.0.3 (February 18, 2014) ##

*No changes*


## Rails 4.0.2 (December 02, 2013) ##

*No changes*


## Rails 4.0.1 (November 01, 2013) ##

*   Fix `has_secure_password` to honor bcrypt-ruby's cost attribute.

    *T.J. Schuck*

*   `inclusion` / `exclusion` validations with ranges will only use the faster
    `Range#cover` for numerical ranges, and the more accurate `Range#include?`
    for non-numerical ones.

    Fixes range validations like `:a..:f` that used to pass with values like `:be`.

    Fixes #10593.

    *Charles Bergeron*


## Rails 4.0.0 (June 25, 2013) ##

*   Fix regression in has_secure_password. When a password is set, but a
    confirmation is an empty string, it would incorrectly save.

    *Steve Klabnik* and *Phillip Calvin*

*   Add `ActiveModel::Errors#full_messages_for`, to return all the error messages
    for a given attribute.

    Example:

        class Person
          include ActiveModel::Validations

          attr_reader :name, :email
          validates_presence_of :name, :email
        end

        person = Person.new
        person.valid?                           # => false
        person.errors.full_messages_for(:name)  # => ["Name can't be blank"]

    *Volodymyr Shatsky*

*   Added a method so that validations can be easily cleared on a model.
    For example:

        class Person
          include ActiveModel::Validations

          validates_uniqueness_of :first_name
          validate :cannot_be_robot

          def cannot_be_robot
            errors.add(:base, 'A person cannot be a robot') if person_is_robot
          end
        end

    Now, if someone runs `Person.clear_validators!`, then the following occurs:

        Person.validators                  # => []
        Person._validate_callbacks.empty?  # => true

    *John Wang*

*   `has_secure_password` does not fail the confirmation validation
    when assigning empty String to `password` and `password_confirmation`.
    Fixes #9535.

    Example:

        # Given User has_secure_password.
        @user.password = ""
        @user.password_confirmation = ""
        @user.valid?(:update) # used to be false

    *Yves Senn*

*   `validates_confirmation_of` does not override writer methods for
    the confirmation attribute if no reader is defined.

    Example:

        class Blog
          def title=(new_title)
            @title = new_title.downcase
          end

          # previously this would override the setter above.
          validates_confirmation_of :title
        end

    *Yves Senn*

*   Add `ActiveModel::Validations::AbsenceValidator`, a validator to check the
    absence of attributes.

        class Person
          include ActiveModel::Validations

          attr_accessor :first_name
          validates_absence_of :first_name
        end

        person = Person.new
        person.first_name = "John"
        person.valid?
        # => false
        person.errors.messages
        # => {:first_name=>["must be blank"]}

    *Roberto Vasquez Angel*

*   `[attribute]_changed?` now returns `false` after a call to `reset_[attribute]!`.

    *Renato Mascarenhas*

*   Observers was extracted from Active Model as `rails-observers` gem.

    *Rafael Mendonça França*

*   Specify type of singular association during serialization.

    *Steve Klabnik*

*   Fixed length validator to correctly handle `nil`. Fixes #7180.

    *Michal Zima*

*   Removed dispensable `require` statements. Make sure to require `active_model` before requiring
    individual parts of the framework.

    *Yves Senn*

*   Use BCrypt's `MIN_COST` in the test environment for speedier tests when using `has_secure_password`.

    *Brian Cardarella + Jeremy Kemper + Trevor Turk*

*   Add `ActiveModel::ForbiddenAttributesProtection`, a simple module to
    protect attributes from mass assignment when non-permitted attributes are passed.

    *DHH + Guillermo Iguaran*

*   `ActiveModel::MassAssignmentSecurity` has been extracted from Active Model and the
    `protected_attributes` gem should be added to Gemfile in order to use
    `attr_accessible` and `attr_protected` macros in your models.

    *Guillermo Iguaran*

*   Due to a change in builder, `nil` and empty strings now generate
    closed tags, so instead of this:

        <pseudonyms nil=\"true\"></pseudonyms>

    it generates this:

        <pseudonyms nil=\"true\"/>

    *Carlos Antonio da Silva*

*   Inclusion/exclusion validators accept a method name passed as a symbol to the
    `:in` option.

    This allows to use dynamic inclusion/exclusion values using methods, besides
    the current lambda/proc support.

    *Gabriel Sobrinho*

*   `ActiveModel::Validation#validates` ability to pass custom exception to the
    `:strict` option.

    *Bogdan Gusiev*

*   Changed `ActiveModel::Serializers::Xml::Serializer#add_associations` to by default
    propagate `:skip_types, :dasherize, :camelize` keys to included associations.
    It can be overridden on each association by explicitly specifying the option on one
    or more associations

    *Anthony Alberto*

*   Changed `ActiveModel::Serializers::JSON.include_root_in_json` default value to false.
    Now, AM Serializers and AR objects have the same default behaviour. Fixes #6578.

        class User < ActiveRecord::Base; end

        class Person
          include ActiveModel::Model
          include ActiveModel::AttributeMethods
          include ActiveModel::Serializers::JSON

          attr_accessor :name, :age

          def attributes
            instance_values
          end
        end

        user.as_json
        => {"id"=>1, "name"=>"Konata Izumi", "age"=>16, "awesome"=>true}
        # root is not included

        person.as_json
        => {"name"=>"Francesco", "age"=>22}
        # root is not included

    *Francesco Rodriguez*

*   Passing false hash values to `validates` will no longer enable the corresponding validators.

    *Steve Purcell*

*   `ConfirmationValidator` error messages will attach to `:#{attribute}_confirmation` instead of `attribute`.

    *Brian Cardarella*

*   Added `ActiveModel::Model`, a mixin to make Ruby objects work with AP out of box.

    *Guillermo Iguaran*

*   `AM::Errors#to_json`: support `:full_messages` parameter.

    *Bogdan Gusiev*

*   Trim down Active Model API by removing `valid?` and `errors.full_messages`.

    *José Valim*

*   When `^` or `$` are used in the regular expression provided to `validates_format_of`
    and the `:multiline` option is not set to true, an exception will be raised. This is
    to prevent security vulnerabilities when using `validates_format_of`. The problem is
    described in detail in the Rails security guide.

    *Jan Berdajs + Egor Homakov*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/activemodel/CHANGELOG.md) for previous changes.
