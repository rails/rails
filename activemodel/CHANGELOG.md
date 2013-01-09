## Rails 3.1.11 (unreleased) ##

## Rails 3.1.10 (Jan 8, 2013) ##

*   No changes.

## Rails 3.1.9 (Jan 2, 2013) ##

*   Due to a change in builder, nil values now generates closed tags, so instead of this:

        <pseudonyms nil=\"true\"></pseudonyms>

    It generates this:

        <pseudonyms nil=\"true\"/>

    *Carlos Antonio da Silva*

## Rails 3.1.8 (Aug 9, 2012) ##

*   No changes.

## Rails 3.1.7 (Jul 26, 2012) ##

*   No changes.

## Rails 3.1.6 (Jun 12, 2012) ##

*   No changes.

## Rails 3.1.5 (May 31, 2012) ##

*   No changes.

## Rails 3.1.1 (October 7, 2011) ##

*   Remove hard dependency on bcrypt-ruby to avoid make ActiveModel dependent on a binary library.
    You must add the gem explicitly to your Gemfile if you want use ActiveModel::SecurePassword:

    gem 'bcrypt-ruby', '~> 3.0.0'

    See GH #2687. *Guillermo Iguaran*

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

Please check [3-0-stable](https://github.com/rails/rails/blob/3-0-stable/activemodel/CHANGELOG) for previous changes.
