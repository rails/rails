*   Add `UniquenessAmongValidator` to validate attribute uniqueness within a model.

    ```ruby
    class User < ApplicationRecord
      # Validates that primary and secondary emails are different
      validates_uniqueness_of_among :primary_email, :secondary_email

      # Validates that all phone numbers are unique
      validates_uniqueness_of_among :home_phone, :work_phone, :mobile_phone,
                                    message: "must be different from other phone numbers"

      # Validates that all tag sets are unique
      validates_uniqueness_of_among :primary_tags, :secondary_tags

      # Validates that metadata fields are unique, treating string and symbol keys as equivalent
      validates_uniqueness_of_among :primary_metadata, :secondary_metadata,
                                    compare_hash_keys_as_strings: true
    end
    ```

    *Zakaria Fatahi*

*   Add `except_on:` option for validation callbacks.

    *Ben Sheldon*

*   Backport `ActiveRecord::Normalization` to `ActiveModel::Attributes::Normalization`

    ```ruby
    class User
      include ActiveModel::Attributes
      include ActiveModel::Attributes::Normalization

      attribute :email, :string

      normalizes :email, with: -> email { email.strip.downcase }
    end

    user = User.new
    user.email =    " CRUISE-CONTROL@EXAMPLE.COM\n"
    user.email # => "cruise-control@example.com"
    ```

    *Sean Doyle*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activemodel/CHANGELOG.md) for previous changes.
