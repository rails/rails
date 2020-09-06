# frozen_string_literal: true

require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/module/anonymous'
require 'action_dispatch/http/mime_type'

module ActionController
  # Wraps the parameters hash into a nested hash. This will allow clients to
  # submit requests without having to specify any root elements.
  #
  # This functionality is enabled in +config/initializers/wrap_parameters.rb+
  # and can be customized.
  #
  # You could also turn it on per controller by setting the format array to
  # a non-empty array:
  #
  #     class UsersController < ApplicationController
  #       wrap_parameters format: [:json, :xml, :url_encoded_form, :multipart_form]
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
  # On Active Record models with no +:include+ or +:exclude+ option set,
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

    require 'mutex_m'

    class Options < Struct.new(:name, :format, :include, :exclude, :klass, :model) # :nodoc:
      include Mutex_m

      def self.from_hash(hash)
        name    = hash[:name]
        format  = Array(hash[:format])
        include = hash[:include] && Array(hash[:include]).collect(&:to_s)
        exclude = hash[:exclude] && Array(hash[:exclude]).collect(&:to_s)
        new name, format, include, exclude, nil, nil
      end

      def initialize(name, format, include, exclude, klass, model) # :nodoc:
        super
        @include_set = include
        @name_set    = name
      end

      def model
        super || self.model = _default_wrap_model
      end

      def include
        return super if @include_set

        m = model
        synchronize do
          return super if @include_set

          @include_set = true

          unless super || exclude
            if m.respond_to?(:attribute_names) && m.attribute_names.any?
              if m.respond_to?(:stored_attributes) && !m.stored_attributes.empty?
                self.include = m.attribute_names + m.stored_attributes.values.flatten.map(&:to_s)
              else
                self.include = m.attribute_names
              end

              if m.respond_to?(:nested_attributes_options) && m.nested_attributes_options.keys.any?
                self.include += m.nested_attributes_options.keys.map do |key|
                  (+key.to_s).concat('_attributes')
                end
              end

              self.include
            end
          end
        end
      end

      def name
        return super if @name_set

        m = model
        synchronize do
          return super if @name_set

          @name_set = true

          unless super || klass.anonymous?
            self.name = m ? m.to_s.demodulize.underscore :
              klass.controller_name.singularize
          end
        end
      end

      private
        # Determine the wrapper model from the controller's name. By convention,
        # this could be done by trying to find the defined model that has the
        # same singular name as the controller. For example, +UsersController+
        # will try to find if the +User+ model exists.
        #
        # This method also does namespace lookup. Foo::Bar::UsersController will
        # try to find Foo::Bar::User, Foo::User and finally User.
        def _default_wrap_model
          return nil if klass.anonymous?
          model_name = klass.name.delete_suffix('Controller').classify

          begin
            if model_klass = model_name.safe_constantize
              model_klass
            else
              namespaces = model_name.split('::')
              namespaces.delete_at(-2)
              break if namespaces.last == model_name
              model_name = namespaces.join('::')
            end
          end until model_klass

          model_klass
        end
    end

    included do
      class_attribute :_wrapper_options, default: Options.from_hash(format: [])
    end

    module ClassMethods
      def _set_wrapper_options(options)
        self._wrapper_options = Options.from_hash(options)
      end

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
      #     # (+person+, in this case) and the list of attribute names
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
          options = options.merge(format: [])
        when Symbol, String
          options = options.merge(name: name_or_model_or_options)
        else
          model = name_or_model_or_options
        end

        opts = Options.from_hash _wrapper_options.to_h.slice(:format).merge(options)
        opts.model = model
        opts.klass = self

        self._wrapper_options = opts
      end

      # Sets the default wrapper key or model which will be used to determine
      # wrapper key and attribute names. Called automatically when the
      # module is inherited.
      def inherited(klass)
        if klass._wrapper_options.format.any?
          params = klass._wrapper_options.dup
          params.klass = klass
          klass._wrapper_options = params
        end
        super
      end
    end

    # Performs parameters wrapping upon the request. Called automatically
    # by the metal call stack.
    def process_action(*)
      _perform_parameter_wrapping if _wrapper_enabled?
      super
    end

    private
      # Returns the wrapper key which will be used to store wrapped parameters.
      def _wrapper_key
        _wrapper_options.name
      end

      # Returns the list of enabled formats.
      def _wrapper_formats
        _wrapper_options.format
      end

      # Returns the list of parameters which will be selected for wrapped.
      def _wrap_parameters(parameters)
        { _wrapper_key => _extract_parameters(parameters) }
      end

      def _extract_parameters(parameters)
        if include_only = _wrapper_options.include
          parameters.slice(*include_only)
        else
          exclude = _wrapper_options.exclude || []
          parameters.except(*(exclude + EXCLUDE_PARAMETERS))
        end
      end

      # Checks if we should perform parameters wrapping.
      def _wrapper_enabled?
        return false unless request.has_content_type?

        ref = request.content_mime_type.ref
        _wrapper_formats.include?(ref) && _wrapper_key && !request.parameters.key?(_wrapper_key)
      end

      def _perform_parameter_wrapping
        wrapped_hash = _wrap_parameters request.request_parameters
        wrapped_keys = request.request_parameters.keys
        wrapped_filtered_hash = _wrap_parameters request.filtered_parameters.slice(*wrapped_keys)

        # This will make the wrapped hash accessible from controller and view.
        request.parameters.merge! wrapped_hash
        request.request_parameters.merge! wrapped_hash

        # This will display the wrapped hash in the log file.
        request.filtered_parameters.merge! wrapped_filtered_hash
      rescue ActionDispatch::Http::Parameters::ParseError
        # swallow parse error exception
      end
  end
end
