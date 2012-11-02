require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/module/anonymous'
require 'action_dispatch/http/mime_types'

module ActionController
  # Wraps the parameters hash into a nested hash. This will allow clients to submit
  # POST requests without having to specify any root elements.
  #
  # This functionality is enabled in +config/initializers/wrap_parameters.rb+
  # and can be customized. If you are upgrading to \Rails 3.1, this file will
  # need to be created for the functionality to be enabled.
  #
  # You could also turn it on per controller by setting the format array to
  # a non-empty array:
  #
  #     class UsersController < ApplicationController
  #       wrap_parameters format: [:json, :xml]
  #     end
  #
  # If you enable +ParamsWrapper+ for +:json+ format, instead of having to
  # send JSON parameters like this:
  #
  #     {"user": {"name": "Konata"}}
  #
  # You can send parameters like this:
  #
  #     {"name": "Konata"}
  #
  # And it will be wrapped into a nested hash with the key name matching the
  # controller's name. For example, if you're posting to +UsersController+,
  # your new +params+ hash will look like this:
  #
  #     {"name" => "Konata", "user" => {"name" => "Konata"}}
  #
  # You can also specify the key in which the parameters should be wrapped to,
  # and also the list of attributes it should wrap by using either +:include+ or
  # +:exclude+ options like this:
  #
  #     class UsersController < ApplicationController
  #       wrap_parameters :person, include: [:username, :password]
  #     end
  #
  # On ActiveRecord models with no +:include+ or +:exclude+ option set,
  # it will only wrap the parameters returned by the class method
  # <tt>attribute_names</tt>.
  #
  # If you're going to pass the parameters to an +ActiveModel+ object (such as
  # <tt>User.new(params[:user])</tt>), you might consider passing the model class to
  # the method instead. The +ParamsWrapper+ will actually try to determine the
  # list of attribute names from the model and only wrap those attributes:
  #
  #     class UsersController < ApplicationController
  #       wrap_parameters Person
  #     end
  #
  # You still could pass +:include+ and +:exclude+ to set the list of attributes
  # you want to wrap.
  #
  # By default, if you don't specify the key in which the parameters would be
  # wrapped to, +ParamsWrapper+ will actually try to determine if there's
  # a model related to it or not. This controller, for example:
  #
  #     class Admin::UsersController < ApplicationController
  #     end
  #
  # will try to check if <tt>Admin::User</tt> or +User+ model exists, and use it to
  # determine the wrapper key respectively. If both models don't exist,
  # it will then fallback to use +user+ as the key.
  module ParamsWrapper
    extend ActiveSupport::Concern

    EXCLUDE_PARAMETERS = %w(authenticity_token _method utf8)

    included do
      class_attribute :_wrapper_options
      self._wrapper_options = { :format => [] }
    end

    module ClassMethods
      # Sets the name of the wrapper key, or the model which +ParamsWrapper+
      # would use to determine the attribute names from.
      #
      # ==== Examples
      #   wrap_parameters format: :xml
      #     # enables the parameter wrapper for XML format
      #
      #   wrap_parameters :person
      #     # wraps parameters into +params[:person]+ hash
      #
      #   wrap_parameters Person
      #     # wraps parameters by determining the wrapper key from Person class
      #     (+person+, in this case) and the list of attribute names
      #
      #   wrap_parameters include: [:username, :title]
      #     # wraps only +:username+ and +:title+ attributes from parameters.
      #
      #   wrap_parameters false
      #     # disables parameters wrapping for this controller altogether.
      #
      # ==== Options
      # * <tt>:format</tt> - The list of formats in which the parameters wrapper
      #   will be enabled.
      # * <tt>:include</tt> - The list of attribute names which parameters wrapper
      #   will wrap into a nested hash.
      # * <tt>:exclude</tt> - The list of attribute names which parameters wrapper
      #   will exclude from a nested hash.
      def wrap_parameters(name_or_model_or_options, options = {})
        model = nil

        case name_or_model_or_options
        when Hash
          options = name_or_model_or_options
        when false
          options = options.merge(:format => [])
        when Symbol, String
          options = options.merge(:name => name_or_model_or_options)
        else
          model = name_or_model_or_options
        end

        _set_wrapper_defaults(_wrapper_options.slice(:format).merge(options), model)
      end

      # Sets the default wrapper key or model which will be used to determine
      # wrapper key and attribute names. Will be called automatically when the
      # module is inherited.
      def inherited(klass)
        if klass._wrapper_options[:format].present?
          klass._set_wrapper_defaults(klass._wrapper_options.slice(:format))
        end
        super
      end

      protected

      # Determine the wrapper model from the controller's name. By convention,
      # this could be done by trying to find the defined model that has the
      # same singularize name as the controller. For example, +UsersController+
      # will try to find if the +User+ model exists.
      #
      # This method also does namespace lookup. Foo::Bar::UsersController will
      # try to find Foo::Bar::User, Foo::User and finally User.
      def _default_wrap_model #:nodoc:
        return nil if self.anonymous?
        model_name = self.name.sub(/Controller$/, '').classify

        begin
          if model_klass = model_name.safe_constantize
            model_klass
          else
            namespaces = model_name.split("::")
            namespaces.delete_at(-2)
            break if namespaces.last == model_name
            model_name = namespaces.join("::")
          end
        end until model_klass

        model_klass
      end

      def _set_wrapper_defaults(options, model=nil)
        options = options.dup

        unless options[:include] || options[:exclude]
          model ||= _default_wrap_model
          if model.respond_to?(:attribute_names) && model.attribute_names.present?
            options[:include] = model.attribute_names
          end
        end

        unless options[:name] || self.anonymous?
          model ||= _default_wrap_model
          options[:name] = model ? model.to_s.demodulize.underscore :
            controller_name.singularize
        end

        options[:include] = Array(options[:include]).collect(&:to_s) if options[:include]
        options[:exclude] = Array(options[:exclude]).collect(&:to_s) if options[:exclude]
        options[:format]  = Array(options[:format])

        self._wrapper_options = options
      end
    end

    # Performs parameters wrapping upon the request. Will be called automatically
    # by the metal call stack.
    def process_action(*args)
      if _wrapper_enabled?
        wrapped_hash = _wrap_parameters request.request_parameters
        wrapped_keys = request.request_parameters.keys
        wrapped_filtered_hash = _wrap_parameters request.filtered_parameters.slice(*wrapped_keys)

        # This will make the wrapped hash accessible from controller and view
        request.parameters.merge! wrapped_hash
        request.request_parameters.merge! wrapped_hash

        # This will make the wrapped hash displayed in the log file
        request.filtered_parameters.merge! wrapped_filtered_hash
      end
      super
    end

    private

      # Returns the wrapper key which will use to stored wrapped parameters.
      def _wrapper_key
        _wrapper_options[:name]
      end

      # Returns the list of enabled formats.
      def _wrapper_formats
        _wrapper_options[:format]
      end

      # Returns the list of parameters which will be selected for wrapped.
      def _wrap_parameters(parameters)
        value = if include_only = _wrapper_options[:include]
          parameters.slice(*include_only)
        else
          exclude = _wrapper_options[:exclude] || []
          parameters.except(*(exclude + EXCLUDE_PARAMETERS))
        end

        { _wrapper_key => value }
      end

      # Checks if we should perform parameters wrapping.
      def _wrapper_enabled?
        ref = request.content_mime_type.try(:ref)
        _wrapper_formats.include?(ref) && _wrapper_key && !request.request_parameters[_wrapper_key]
      end
  end
end
