# frozen_string_literal: true

module ActiveRecord # :nodoc:
  module Normalization
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Attributes::Normalization
    end

    ##
    # :method: normalize_attribute
    # :call-seq: normalize_attribute(name)
    #
    # See ActiveModel::Attributes::Normalization::ClassMethods#normalize_attribute.

    module ClassMethods
      ##
      # :method: normalizes
      # :call-seq: normalizes(*names, with:, apply_to_nil: false)
      #
      # See ActiveModel::Attributes::Normalization::ClassMethods#normalizes.
      #
      # To prevent confusion, normalization will not be applied
      # when the attribute is fetched from the database. This means that if a
      # record was persisted before the normalization was declared, the record's
      # attribute will not be normalized until either it is assigned a new
      # value, or it is explicitly migrated via Normalization#normalize_attribute.
      #
      # Be aware that if your app was created before Rails 7.1, and your app
      # marshals instances of the targeted model (for example, when caching),
      # then you should set ActiveRecord.marshalling_format_version to +7.1+ or
      # higher via either <tt>config.load_defaults 7.1</tt> or
      # <tt>config.active_record.marshalling_format_version = 7.1</tt>.
      # Otherwise, +Marshal+ may attempt to serialize the normalization +Proc+
      # and raise +TypeError+.
      #
      # ==== Examples
      #
      #   class User < ActiveRecord::Base
      #     normalizes :email, with: -> email { email.strip.downcase }
      #     normalizes :phone, with: -> phone { phone.delete("^0-9").delete_prefix("1") }
      #   end
      #
      #   user = User.create(email: " CRUISE-CONTROL@EXAMPLE.COM\n")
      #   user.email                  # => "cruise-control@example.com"
      #
      #   user = User.find_by(email: "\tCRUISE-CONTROL@EXAMPLE.COM ")
      #   user.email                  # => "cruise-control@example.com"
      #   user.email_before_type_cast # => "cruise-control@example.com"
      #
      #   User.where(email: "\tCRUISE-CONTROL@EXAMPLE.COM ").count         # => 1
      #   User.where(["email = ?", "\tCRUISE-CONTROL@EXAMPLE.COM "]).count # => 0
      #
      #   User.exists?(email: "\tCRUISE-CONTROL@EXAMPLE.COM ")         # => true
      #   User.exists?(["email = ?", "\tCRUISE-CONTROL@EXAMPLE.COM "]) # => false
      #
      #   User.normalize_value_for(:phone, "+1 (555) 867-5309") # => "5558675309"

      ##
      # :method: normalize_value_for
      # :call-seq: normalize_value_for(name, value)
      #
      # See ActiveModel::Attributes::Normalization::ClassMethods#normalize_value_for.
      #
      # ==== Examples
      #
      #   class User < ActiveRecord::Base
      #     normalizes :email, with: -> email { email.strip.downcase }
      #   end
      #
      #   User.normalize_value_for(:email, " CRUISE-CONTROL@EXAMPLE.COM\n")
      #   # => "cruise-control@example.com"
    end
  end
end
