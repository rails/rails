## Rails 3.2.6 (Jun 12, 2012)

*   No changes.

## Rails 3.2.4 (May 31, 2012) ##

*   No changes.

## Rails 3.2.3 (March 30, 2012) ##

*   No changes.


## Rails 3.2.2 (March 1, 2012) ##

*   No changes.


## Rails 3.2.1 (January 26, 2012) ##

*   No changes.


## Rails 3.2.0 (January 20, 2012) ##

*   Deprecated `define_attr_method` in `ActiveModel::AttributeMethods`, because this only existed to
    support methods like `set_table_name` in Active Record, which are themselves being deprecated. *Jon Leighton*

*   Add ActiveModel::Errors#added? to check if a specific error has been added *Martin Svalin*

*   Add ability to define strict validation(with :strict => true option) that always raises exception when fails *Bogdan Gusiev*

*   Deprecate "Model.model_name.partial_path" in favor of "model.to_partial_path" *Grant Hutchins, Peter Jaros*

*   Provide mass_assignment_sanitizer as an easy API to replace the sanitizer behavior. Also support both :logger (default) and :strict sanitizer behavior *Bogdan Gusiev*


## Rails 3.1.0 (August 30, 2011) ##

*   Alternate I18n namespace lookup is no longer supported.
    Instead of "activerecord.models.admins.post", do "activerecord.models.admins/post" instead *José Valim*

*   attr_accessible and friends now accepts :as as option to specify a role *Josh Kalderimis*

*   Add support for proc or lambda as an option for InclusionValidator,
    ExclusionValidator, and FormatValidator *Prem Sichanugrist*

    You can now supply Proc, lambda, or anything that respond to #call in those
    validations, and it will be called with current record as an argument.
    That given proc or lambda must returns an object which respond to #include? for
    InclusionValidator and ExclusionValidator, and returns a regular expression
    object for FormatValidator.

*   Added ActiveModel::SecurePassword to encapsulate dead-simple password usage with BCrypt encryption and salting *DHH*

*   ActiveModel::AttributeMethods allows attributes to be defined on demand *Alexander Uvarov*

*   Add support for selectively enabling/disabling observers *Myron Marston*


## Rails 3.0.7 (April 18, 2011) ##

*   No changes.


## Rails 3.0.6 (April 5, 2011) ##

*   Fix when database column name has some symbolic characters (e.g. Oracle CASE# VARCHAR2(20)) #5818 #6850 *Robert Pankowecki, Santiago Pastorino*

*   Fix length validation for fixnums #6556 *Andriy Tyurnikov*

*   Fix i18n key collision with namespaced models #6448 *yves.senn*


## Rails 3.0.5 (February 26, 2011) ##

*   No changes.


## Rails 3.0.4 (February 8, 2011) ##

*   No changes.


## Rails 3.0.3 (November 16, 2010) ##

*   No changes.


## Rails 3.0.2 (November 15, 2010) ##

*   No changes


## Rails 3.0.1 (October 15, 2010) ##

*   No Changes, just a version bump.


## Rails 3.0.0 (August 29, 2010) ##

*   Added ActiveModel::MassAssignmentSecurity *Eric Chapweske, Josh Kalderimis*

*   JSON supports a custom root option: to_json(:root => 'custom')  #4515 *Jatinder Singh*

*   #new_record? and #destroyed? were removed from ActiveModel::Lint. Use
    persisted? instead. A model is persisted if it's not a new_record? and it was
    not destroyed? *MG*

*   Added validations reflection in ActiveModel::Validations *JV*

        Model.validators
        Model.validators_on(:field)

*   #to_key was added to ActiveModel::Lint so we can generate DOM IDs for
    AMo objects with composite keys *MG*

*   ActiveModel::Observer#add_observer!

    It has a custom hook to define after_find that should really be in a
    ActiveRecord::Observer subclass:

        def add_observer!(klass)
          klass.add_observer(self)
          klass.class_eval 'def after_find() end' unless klass.respond_to?(:after_find)
        end

*   Change the ActiveModel::Base.include_root_in_json default to true for Rails 3 *DHH*

*   Add validates_format_of :without => /regexp/ option. #430 *Elliot Winkler, Peer Allan*

    Example :

          validates_format_of :subdomain, :without => /www|admin|mail/

*   Introduce validates_with to encapsulate attribute validations in a class.  #2630 *Jeff Dean*

*   Extracted from Active Record and Active Resource.
