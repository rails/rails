## Rails 4.0.0 (unreleased) ##

*   Add `ActiveModel::ForbiddenAttributesProtection`, a simple module to
    protect attributes from mass assignment when non-permitted attributes are passed.

    *DHH + Guillermo Iguaran*

*   `ActiveModel::MassAssignmentSecurity` has been extracted from Active Model and the
    `protected_attributes` gem should be added to Gemfile in order to use
    `attr_accessible` and `attr_protected` macros in your models.

    *Guillermo Iguaran*

*   Due to a change in builder, nil values and empty strings now generates
    closed tags, so instead of this:

        <pseudonyms nil=\"true\"></pseudonyms>

    It generates this:

        <pseudonyms nil=\"true\"/>

    *Carlos Antonio da Silva*

*   Changed inclusion and exclusion validators to accept a symbol for `:in` option.

    This allows to use dynamic inclusion/exclusion values using methods, besides the current lambda/proc support.

    *Gabriel Sobrinho*

*   `AM::Validation#validates` ability to pass custom exception to `:strict` option.

    *Bogdan Gusiev*

*   Changed `ActiveModel::Serializers::Xml::Serializer#add_associations` to by default
    propagate `:skip_types, :dasherize, :camelize` keys to included associations.
    It can be overriden on each association by explicitly specifying the option on one
    or more associations

    *Anthony Alberto*

*   Changed `AM::Serializers::JSON.include_root_in_json' default value to false.
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

*   Passing false hash values to `validates` will no longer enable the corresponding validators *Steve Purcell*

*   `ConfirmationValidator` error messages will attach to `:#{attribute}_confirmation` instead of `attribute` *Brian Cardarella*

*   Added ActiveModel::Model, a mixin to make Ruby objects work with AP out of box *Guillermo Iguaran*

*   `AM::Errors#to_json`: support `:full_messages` parameter *Bogdan Gusiev*

*   Trim down Active Model API by removing `valid?` and `errors.full_messages` *José Valim*

*   When `^` or `$` are used in the regular expression provided to `validates_format_of` and the :multiline option is not set to true, an exception will be raised. This is to prevent security vulnerabilities when using `validates_format_of`. The problem is described in detail in the Rails security guide *Jan Berdajs + Egor Homakov*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/activemodel/CHANGELOG.md) for previous changes.
