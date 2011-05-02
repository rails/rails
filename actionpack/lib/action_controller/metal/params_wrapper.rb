require 'active_support/core_ext/class/attribute'
require 'action_dispatch/http/mime_types'

module ActionController
  # Wraps parameters hash into nested hash. This will allow client to submit
  # POST request without having to specify a root element in it.
  #
  # By default, this functionality won't be enabled by default. You can enable
  # it globally by setting +ActionController::Base.wrap_parameters+:
  #
  #     ActionController::Base.wrap_parameters = [:json]
  #
  # You could also turn it on per controller by setting the format array to
  # non-empty array:
  #
  #     class UsersController < ApplicationController
  #       wrap_parameters :format => [:json, :xml]
  #     end
  #
  # If you enable +ParamsWrapper+ for +:json+ format. Instead of having to
  # send JSON parameters like this:
  #
  #     {"user": {"name": "Konata"}}
  #
  # You can now just send a parameters like this:
  #
  #     {"name": "Konata"}
  #
  # And it will be wrapped into a nested hash with the key name matching
  # controller's name. For example, if you're posting to +UsersController+,
  # your new +params+ hash will look like this:
  #
  #     {"name" => "Konata", "user" => {"name" => "Konata"}}
  #
  # You can also specify the key in which the parameters should be wrapped to,
  # and also the list of attributes it should wrap by using either +:only+ or
  # +:except+ options like this:
  #
  #     class UsersController < ApplicationController
  #       wrap_parameters :person, :only => [:username, :password]
  #     end
  #
  # If you're going to pass the parameters to an +ActiveModel+ object (such as
  # +User.new(params[:user])+), you might consider passing the model class to
  # the method instead. The +ParamsWrapper+ will actually try to determine the
  # list of attribute names from the model and only wrap those attributes:
  #
  #     class UsersController < ApplicationController
  #       wrap_parameters Person
  #     end
  #
  # You still could pass +:only+ and +:except+ to set the list of attributes
  # you want to wrap.
  #
  # By default, if you don't specify the key in which the parameters would be
  # wrapped to, +ParamsWrapper+ will actually try to determine if there's
  # a model related to it or not. This controller, for example:
  #
  #     class Admin::UsersController < ApplicationController
  #     end
  #
  # will try to check if +Admin::User+ or +User+ model exists, and use it to
  # determine the wrapper key respectively. If both of the model doesn't exists,
  # it will then fallback to use +user+ as the key.
  module ParamsWrapper
    extend ActiveSupport::Concern

    EXCLUDE_PARAMETERS = %w(authenticity_token _method utf8)

    included do
      class_attribute :_wrapper_options
      self._wrapper_options = {:format => []}
    end

    module ClassMethods
      # Sets the name of the wrapper key, or the model which +ParamsWrapper+
      # would use to determine the attribute names from.
      #
      # ==== Examples
      #   wrap_parameters :format => :xml
      #     # enables the parmeter wrappes for XML format
      #
      #   wrap_parameters :person
      #     # wraps parameters into +params[:person]+ hash
      #
      #   wrap_parameters Person
      #     # wraps parameters by determine the wrapper key from Person class
      #     (+person+, in this case) and the list of attribute names
      #
      #   wrap_parameters :only => [:username, :title]
      #     # wraps only +:username+ and +:title+ attributes from parameters.
      #
      #   wrap_parameters false
      #     # disable parameters wrapping for this controller altogether.
      #
      # ==== Options
      # * <tt>:format</tt> - The list of formats in which the parameters wrapper
      #   will be enabled.
      # * <tt>:only</tt> - The list of attribute names which parmeters wrapper
      #   will wrap into a nested hash.
      # * <tt>:only</tt> - The list of attribute names which parmeters wrapper
      #   will exclude from a nested hash.
      def wrap_parameters(name_or_model_or_options, options = {})
        if !name_or_model_or_options.is_a? Hash
          if name_or_model_or_options != false
            options = options.merge(:name_or_model => name_or_model_or_options)
          else
            options = opions.merge(:format => [])
          end
        else
          options = name_or_model_or_options
        end

        options[:name_or_model] ||= _default_wrap_model
        self._wrapper_options = self._wrapper_options.merge(options)
      end

      # Sets the default wrapper key or model which will be used to determine
      # wrapper key and attribute names. Will be called automatically when the
      # module is inherited.
      def inherited(klass)
        if klass._wrapper_options[:format].present?
          klass._wrapper_options = klass._wrapper_options.merge(:name_or_model => klass._default_wrap_model)
        end
        super
      end

      # Determine the wrapper model from the controller's name. By convention,
      # this could be done by trying to find the defined model that has the
      # same singularize name as the controller. For example, +UsersController+
      # will try to find if the +User+ model exists.
      def _default_wrap_model
        model_name = self.name.sub(/Controller$/, '').singularize

        begin
          model_klass = model_name.constantize
        rescue NameError => e
          unscoped_model_name = model_name.split("::", 2).last
          break if unscoped_model_name == model_name
          model_name = unscoped_model_name
        end until model_klass

        model_klass
      end
    end

    # Performs parameters wrapping upon the request. Will be called automatically
    # by the metal call stack.
    def process_action(*args)
      if _wrapper_enabled?
        wrapped_hash = { _wrapper_key => request.request_parameters.slice(*_wrapped_keys) }
        wrapped_filtered_hash = { _wrapper_key => request.filtered_parameters.slice(*_wrapped_keys) }

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
        @_wrapper_key ||= if _wrapper_options[:name_or_model]
            _wrapper_options[:name_or_model].to_s.demodulize.underscore
          else
            self.class.controller_name.singularize
          end
      end

      # Returns the list of parameters which will be selected for wrapped.
      def _wrapped_keys
        @_wrapped_keys ||= if _wrapper_options[:only]
            Array(_wrapper_options[:only]).collect(&:to_s)
          elsif _wrapper_options[:except]
            request.request_parameters.keys - Array(_wrapper_options[:except]).collect(&:to_s) - EXCLUDE_PARAMETERS
          elsif _wrapper_options[:name_or_model].respond_to?(:column_names)
            _wrapper_options[:name_or_model].column_names
          else
            request.request_parameters.keys - EXCLUDE_PARAMETERS
          end
      end

      # Returns the list of enabled formats.
      def _wrapper_formats
        Array(_wrapper_options[:format])
      end

      # Checks if we should perform parameters wrapping.
      def _wrapper_enabled?
        _wrapper_formats.any?{ |format| format == request.content_mime_type.try(:ref) } && request.request_parameters[_wrapper_key].nil?
      end
  end
end
