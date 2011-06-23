require 'active_support/core_ext/class/attribute.rb'
require 'active_support/core_ext/array/wrap'
require 'active_model/mass_assignment_security/permission_set'

module ActiveModel
  # = Active Model Mass-Assignment Security
  module MassAssignmentSecurity
    extend ActiveSupport::Concern

    included do
      class_attribute :_accessible_attributes
      class_attribute :_protected_attributes
      class_attribute :_active_authorizer
    end

    # Mass assignment security provides an interface for protecting attributes
    # from end-user assignment. For more complex permissions, mass assignment security
    # may be handled outside the model by extending a non-ActiveRecord class,
    # such as a controller, with this behavior.
    #
    # For example, a logged in user may need to assign additional attributes depending
    # on their role:
    #
    #   class AccountsController < ApplicationController
    #     include ActiveModel::MassAssignmentSecurity
    #
    #     attr_accessible :first_name, :last_name
    #     attr_accessible :first_name, :last_name, :plan_id, :as => :admin
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
    module ClassMethods
      # Attributes named in this macro are protected from mass-assignment
      # whenever attributes are sanitized before assignment. A role for the
      # attributes is optional, if no role is provided then :default is used.
      # A role can be defined by using the :as option.
      #
      # Mass-assignment to these attributes will simply be ignored, to assign
      # to them you can use direct writer methods. This is meant to protect
      # sensitive attributes from being overwritten by malicious users
      # tampering with URLs or forms. Example:
      #
      #   class Customer
      #     include ActiveModel::MassAssignmentSecurity
      #
      #     attr_accessor :name, :credit_rating
      #
      #     attr_protected :credit_rating, :last_login
      #     attr_protected :last_login, :as => :admin
      #
      #     def assign_attributes(values, options = {})
      #       sanitize_for_mass_assignment(values, options[:as]).each do |k, v|
      #         send("#{k}=", v)
      #       end
      #     end
      #   end
      #
      # When using the :default role :
      #
      #   customer = Customer.new
      #   customer.assign_attributes({ "name" => "David", "credit_rating" => "Excellent", :last_login => 1.day.ago }, :as => :default)
      #   customer.name          # => "David"
      #   customer.credit_rating # => nil
      #   customer.last_login    # => nil
      #
      #   customer.credit_rating = "Average"
      #   customer.credit_rating # => "Average"
      #
      # And using the :admin role :
      #
      #   customer = Customer.new
      #   customer.assign_attributes({ "name" => "David", "credit_rating" => "Excellent", :last_login => 1.day.ago }, :as => :admin)
      #   customer.name          # => "David"
      #   customer.credit_rating # => "Excellent"
      #   customer.last_login    # => nil
      #
      # To start from an all-closed default and enable attributes as needed,
      # have a look at +attr_accessible+.
      #
      # Note that using <tt>Hash#except</tt> or <tt>Hash#slice</tt> in place of +attr_protected+
      # to sanitize attributes won't provide sufficient protection.
      def attr_protected(*args)
        options = args.extract_options!
        role = options[:as] || :default

        self._protected_attributes = protected_attributes_configs.dup

        Array.wrap(role).each do |name|
          self._protected_attributes[name] = self.protected_attributes(name) + args
        end

        self._active_authorizer = self._protected_attributes
      end

      # Specifies a white list of model attributes that can be set via
      # mass-assignment.
      #
      # Like +attr_protected+, a role for the attributes is optional,
      # if no role is provided then :default is used. A role can be defined by
      # using the :as option.
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
      #     attr_accessible :name
      #     attr_accessible :name, :credit_rating, :as => :admin
      #
      #     def assign_attributes(values, options = {})
      #       sanitize_for_mass_assignment(values, options[:as]).each do |k, v|
      #         send("#{k}=", v)
      #       end
      #     end
      #   end
      #
      # When using the :default role :
      #
      #   customer = Customer.new
      #   customer.assign_attributes({ "name" => "David", "credit_rating" => "Excellent", :last_login => 1.day.ago }, :as => :default)
      #   customer.name          # => "David"
      #   customer.credit_rating # => nil
      #
      #   customer.credit_rating = "Average"
      #   customer.credit_rating # => "Average"
      #
      # And using the :admin role :
      #
      #   customer = Customer.new
      #   customer.assign_attributes({ "name" => "David", "credit_rating" => "Excellent", :last_login => 1.day.ago }, :as => :admin)
      #   customer.name          # => "David"
      #   customer.credit_rating # => "Excellent"
      #
      # Note that using <tt>Hash#except</tt> or <tt>Hash#slice</tt> in place of +attr_accessible+
      # to sanitize attributes won't provide sufficient protection.
      def attr_accessible(*args)
        options = args.extract_options!
        role = options[:as] || :default

        self._accessible_attributes = accessible_attributes_configs.dup

        Array.wrap(role).each do |name|
          self._accessible_attributes[name] = self.accessible_attributes(name) + args
        end

        self._active_authorizer = self._accessible_attributes
      end

      def protected_attributes(role = :default)
        protected_attributes_configs[role]
      end

      def accessible_attributes(role = :default)
        accessible_attributes_configs[role]
      end

      def active_authorizers
        self._active_authorizer ||= protected_attributes_configs
      end
      alias active_authorizer active_authorizers

      def attributes_protected_by_default
        []
      end

      private

      def protected_attributes_configs
        self._protected_attributes ||= begin
          default_black_list = BlackList.new(attributes_protected_by_default).tap do |w|
            w.logger = self.logger if self.respond_to?(:logger)
          end
          Hash.new(default_black_list)
        end
      end

      def accessible_attributes_configs
        self._accessible_attributes ||= begin
          default_white_list = WhiteList.new.tap { |w| w.logger = self.logger if self.respond_to?(:logger) }
          Hash.new(default_white_list)
        end
      end
    end

  protected

    def sanitize_for_mass_assignment(attributes, role = :default)
      mass_assignment_authorizer(role).sanitize(attributes)
    end

    def mass_assignment_authorizer(role = :default)
      self.class.active_authorizer[role]
    end
  end
end
