require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/string/inflections'
require 'active_model/mass_assignment_security/permission_set'
require 'active_model/mass_assignment_security/sanitizer'

module ActiveModel
  # == Active Model Mass-Assignment Security
  #
  # Mass assignment security provides an interface for protecting attributes
  # from end-user assignment. For more complex permissions, mass assignment
  # security may be handled outside the model by extending a non-ActiveRecord
  # class, such as a controller, with this behavior.
  #
  # For example, a logged in user may need to assign additional attributes
  # depending on their role:
  #
  #   class AccountsController < ApplicationController
  #     include ActiveModel::MassAssignmentSecurity
  #
  #     attr_accessible :first_name, :last_name
  #     attr_accessible :first_name, :last_name, :plan_id, as: :admin
  #
  #     def update
  #       ...
  #       @account.update_attributes(account_params)
  #       ...
  #     end
  #
  #     protected
  #
  #     def account_params
  #       role = admin ? :admin : :default
  #       sanitize_for_mass_assignment(params[:account], role)
  #     end
  #
  #   end
  #
  # === Configuration options
  #
  # * <tt>mass_assignment_sanitizer</tt> - Defines sanitize method. Possible
  #   values are:
  #   * <tt>:logger</tt> (default) - writes filtered attributes to logger
  #   * <tt>:strict</tt> - raise <tt>ActiveModel::MassAssignmentSecurity::Error</tt>
  #     on any protected attribute update.
  #
  # You can specify your own sanitizer object eg. <tt>MySanitizer.new</tt>.
  # See <tt>ActiveModel::MassAssignmentSecurity::LoggerSanitizer</tt> for
  # example implementation.
  module MassAssignmentSecurity
    extend ActiveSupport::Concern

    included do
      class_attribute :_accessible_attributes, instance_writer: false
      class_attribute :_protected_attributes,  instance_writer: false
      class_attribute :_active_authorizer,     instance_writer: false

      class_attribute :_mass_assignment_sanitizer, instance_writer: false
      self.mass_assignment_sanitizer = :logger
    end

    module ClassMethods
      # Attributes named in this macro are protected from mass-assignment
      # whenever attributes are sanitized before assignment. A role for the
      # attributes is optional, if no role is provided then <tt>:default</tt>
      # is used. A role can be defined by using the <tt>:as</tt> option with a
      # symbol or an array of symbols as the value.
      #
      # Mass-assignment to these attributes will simply be ignored, to assign
      # to them you can use direct writer methods. This is meant to protect
      # sensitive attributes from being overwritten by malicious users
      # tampering with URLs or forms.
      #
      #   class Customer
      #     include ActiveModel::MassAssignmentSecurity
      #
      #     attr_accessor :name, :email, :logins_count
      #
      #     attr_protected :logins_count
      #     # Suppose that admin can not change email for customer
      #     attr_protected :logins_count, :email, as: :admin
      #
      #     def assign_attributes(values, options = {})
      #       sanitize_for_mass_assignment(values, options[:as]).each do |k, v|
      #         send("#{k}=", v)
      #       end
      #     end
      #   end
      #
      # When using the <tt>:default</tt> role:
      #
      #   customer = Customer.new
      #   customer.assign_attributes({ name: 'David', email: 'a@b.com', logins_count: 5 }, as: :default)
      #   customer.name         # => "David"
      #   customer.email        # => "a@b.com"
      #   customer.logins_count # => nil
      #
      # And using the <tt>:admin</tt> role:
      #
      #   customer = Customer.new
      #   customer.assign_attributes({ name: 'David', email: 'a@b.com', logins_count: 5}, as: :admin)
      #   customer.name         # => "David"
      #   customer.email        # => nil
      #   customer.logins_count # => nil
      #
      #   customer.email = 'c@d.com'
      #   customer.email # => "c@d.com"
      #
      # To start from an all-closed default and enable attributes as needed,
      # have a look at +attr_accessible+.
      #
      # Note that using <tt>Hash#except</tt> or <tt>Hash#slice</tt> in place of
      # +attr_protected+ to sanitize attributes provides basically the same
      # functionality, but it makes a bit tricky to deal with nested attributes.
      def attr_protected(*args)
        options = args.extract_options!
        role = options[:as] || :default

        self._protected_attributes = protected_attributes_configs.dup

        Array(role).each do |name|
          self._protected_attributes[name] = self.protected_attributes(name) + args
        end

        self._active_authorizer = self._protected_attributes
      end

      # Specifies a white list of model attributes that can be set via
      # mass-assignment.
      #
      # Like +attr_protected+, a role for the attributes is optional,
      # if no role is provided then <tt>:default</tt> is used. A role can be
      # defined by using the <tt>:as</tt> option with a symbol or an array of
      # symbols as the value.
      #
      # This is the opposite of the +attr_protected+ macro: Mass-assignment
      # will only set attributes in this list, to assign to the rest of
      # attributes you can use direct writer methods. This is meant to protect
      # sensitive attributes from being overwritten by malicious users
      # tampering with URLs or forms. If you'd rather start from an all-open
      # default and restrict attributes as needed, have a look at
      # +attr_protected+.
      #
      #   class Customer
      #     include ActiveModel::MassAssignmentSecurity
      #
      #     attr_accessor :name, :credit_rating
      #
      #     # Both admin and default user can change name of a customer
      #     attr_accessible :name, as: [:admin, :default]
      #     # Only admin can change credit rating of a customer
      #     attr_accessible :credit_rating, as: :admin
      #
      #     def assign_attributes(values, options = {})
      #       sanitize_for_mass_assignment(values, options[:as]).each do |k, v|
      #         send("#{k}=", v)
      #       end
      #     end
      #   end
      #
      # When using the <tt>:default</tt> role:
      #
      #   customer = Customer.new
      #   customer.assign_attributes({ name: 'David', credit_rating: 'Excellent', last_login: 1.day.ago }, as: :default)
      #   customer.name          # => "David"
      #   customer.credit_rating # => nil
      #
      #   customer.credit_rating = 'Average'
      #   customer.credit_rating # => "Average"
      #
      # And using the <tt>:admin</tt> role:
      #
      #   customer = Customer.new
      #   customer.assign_attributes({ name: 'David', credit_rating: 'Excellent', last_login: 1.day.ago }, as: :admin)
      #   customer.name          # => "David"
      #   customer.credit_rating # => "Excellent"
      #
      # Note that using <tt>Hash#except</tt> or <tt>Hash#slice</tt> in place of
      # +attr_accessible+ to sanitize attributes provides basically the same
      # functionality, but it makes a bit tricky to deal with nested attributes.
      def attr_accessible(*args)
        options = args.extract_options!
        role = options[:as] || :default

        self._accessible_attributes = accessible_attributes_configs.dup

        Array(role).each do |name|
          self._accessible_attributes[name] = self.accessible_attributes(name) + args
        end

        self._active_authorizer = self._accessible_attributes
      end

      # Returns an instance of <tt>ActiveModel::MassAssignmentSecurity::BlackList</tt>
      # with the attributes protected by #attr_protected method. If no +role+
      # is provided, then <tt>:default</tt> is used.
      #
      #   class Customer
      #     include ActiveModel::MassAssignmentSecurity
      #
      #     attr_accessor :name, :email, :logins_count
      #
      #     attr_protected :logins_count
      #     attr_protected :logins_count, :email, as: :admin
      #   end
      #
      #   Customer.protected_attributes
      #   # => #<ActiveModel::MassAssignmentSecurity::BlackList: {"logins_count"}>
      #
      #   Customer.protected_attributes(:default)
      #   # => #<ActiveModel::MassAssignmentSecurity::BlackList: {"logins_count"}>
      #
      #   Customer.protected_attributes(:admin)
      #   # => #<ActiveModel::MassAssignmentSecurity::BlackList: {"logins_count", "email"}>
      def protected_attributes(role = :default)
        protected_attributes_configs[role]
      end

      # Returns an instance of <tt>ActiveModel::MassAssignmentSecurity::WhiteList</tt>
      # with the attributes protected by #attr_accessible method. If no +role+
      # is provided, then <tt>:default</tt> is used.
      #
      #   class Customer
      #     include ActiveModel::MassAssignmentSecurity
      #
      #     attr_accessor :name, :credit_rating
      #
      #     attr_accessible :name, as: [:admin, :default]
      #     attr_accessible :credit_rating, as: :admin
      #   end
      #
      #   Customer.accessible_attributes
      #   # => #<ActiveModel::MassAssignmentSecurity::WhiteList: {"name"}>
      #
      #   Customer.accessible_attributes(:default)
      #   # => #<ActiveModel::MassAssignmentSecurity::WhiteList: {"name"}>
      #
      #   Customer.accessible_attributes(:admin)
      #   # => #<ActiveModel::MassAssignmentSecurity::WhiteList: {"name", "credit_rating"}>
      def accessible_attributes(role = :default)
        accessible_attributes_configs[role]
      end

      # Returns a hash with the protected attributes (by #attr_accessible or
      # #attr_protected) per role.
      #
      #   class Customer
      #     include ActiveModel::MassAssignmentSecurity
      #
      #     attr_accessor :name, :credit_rating
      #
      #     attr_accessible :name, as: [:admin, :default]
      #     attr_accessible :credit_rating, as: :admin
      #   end
      #
      #   Customer.active_authorizers
      #   # => {
      #   #       :admin=> #<ActiveModel::MassAssignmentSecurity::WhiteList: {"name", "credit_rating"}>,
      #   #       :default=>#<ActiveModel::MassAssignmentSecurity::WhiteList: {"name"}>
      #   #    }
      def active_authorizers
        self._active_authorizer ||= protected_attributes_configs
      end
      alias active_authorizer active_authorizers

      # Returns an empty array by default. You can still override this to define
      # the default attributes protected by #attr_protected method.
      #
      #   class Customer
      #     include ActiveModel::MassAssignmentSecurity
      #
      #     def self.attributes_protected_by_default
      #       [:name]
      #     end
      #   end
      #
      #   Customer.protected_attributes
      #   # => #<ActiveModel::MassAssignmentSecurity::BlackList: {:name}>
      def attributes_protected_by_default
        []
      end

      # Defines sanitize method.
      #
      #   class Customer
      #     include ActiveModel::MassAssignmentSecurity
      #
      #     attr_accessor :name
      #
      #     attr_protected :name
      #
      #     def assign_attributes(values)
      #       sanitize_for_mass_assignment(values).each do |k, v|
      #         send("#{k}=", v)
      #       end
      #     end
      #   end
      #
      #   # See ActiveModel::MassAssignmentSecurity::StrictSanitizer for more information.
      #   Customer.mass_assignment_sanitizer = :strict
      #
      #   customer = Customer.new
      #   customer.assign_attributes(name: 'David')
      #   # => ActiveModel::MassAssignmentSecurity::Error: Can't mass-assign protected attributes for Customer: name
      #
      # Also, you can specify your own sanitizer object.
      #
      #   class CustomSanitizer < ActiveModel::MassAssignmentSecurity::Sanitizer
      #     def process_removed_attributes(klass, attrs)
      #       raise StandardError
      #     end
      #   end
      #
      #   Customer.mass_assignment_sanitizer = CustomSanitizer.new
      #
      #   customer = Customer.new
      #   customer.assign_attributes(name: 'David')
      #   # => StandardError: StandardError
      def mass_assignment_sanitizer=(value)
        self._mass_assignment_sanitizer = if value.is_a?(Symbol)
          const_get(:"#{value.to_s.camelize}Sanitizer").new(self)
        else
          value
        end
      end

      private

      def protected_attributes_configs
        self._protected_attributes ||= begin
          Hash.new { |h,k| h[k] = BlackList.new(attributes_protected_by_default) }
        end
      end

      def accessible_attributes_configs
        self._accessible_attributes ||= begin
          Hash.new { |h,k| h[k] = WhiteList.new }
        end
      end
    end

  protected

    def sanitize_for_mass_assignment(attributes, role = nil) #:nodoc:
      _mass_assignment_sanitizer.sanitize(self.class, attributes, mass_assignment_authorizer(role))
    end

    def mass_assignment_authorizer(role) #:nodoc:
      self.class.active_authorizer[role || :default]
    end
  end
end
