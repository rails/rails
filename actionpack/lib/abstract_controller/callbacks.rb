# frozen_string_literal: true

# :markup: markdown

module AbstractController
  # # Abstract Controller Callbacks
  #
  # Abstract Controller provides hooks during the life cycle of a controller
  # action. Callbacks allow you to trigger logic during this cycle. Available
  # callbacks are:
  #
  # *   `after_action`
  # *   `append_after_action`
  # *   `append_around_action`
  # *   `append_before_action`
  # *   `around_action`
  # *   `before_action`
  # *   `innermost_after_action`
  # *   `innermost_around_action`
  # *   `innermost_before_action`
  # *   `outermost_after_action`
  # *   `outermost_around_action`
  # *   `outermost_before_action`
  # *   `prepend_after_action`
  # *   `prepend_around_action`
  # *   `prepend_before_action`
  # *   `skip_after_action`
  # *   `skip_around_action`
  # *   `skip_before_action`
  #
  # Callbacks run in the order they are registered, and the ones inherited from a
  # parent controller come first. Think of the chain as a set of layers wrapped
  # around the action: the callbacks registered first are the outermost ones, the
  # ones registered last are the closest to the action.
  #
  # `prepend_before_action` and its siblings move a callback to the front of the
  # chain, and the `:innermost` and `:outermost` options pin it to one end of it,
  # where no regular callback registered later on, by a subclass or otherwise,
  # can displace it:
  #
  #     class ApplicationController < ActionController::Base
  #       before_action :set_current_tenant, outermost: true
  #       before_action :authorize_record, innermost: true, only: %i[ show edit ]
  #     end
  #
  #     class ArticlesController < ApplicationController
  #       before_action :set_article # runs after :set_current_tenant, before :authorize_record
  #     end
  #
  # The `innermost_*_action` and `outermost_*_action` callbacks are shorthands for
  # the same options.
  module Callbacks
    extend ActiveSupport::Concern

    # Uses ActiveSupport::Callbacks as the base functionality. For more details on
    # the whole callback system, read the documentation for
    # ActiveSupport::Callbacks.
    include ActiveSupport::Callbacks

    DEFAULT_INTERNAL_METHODS = [:_run_process_action_callbacks].freeze # :nodoc:

    included do
      define_callbacks :process_action,
                       terminator: ->(controller, result_lambda) { result_lambda.call; controller.performed? },
                       skip_after_callbacks_if_terminated: true
      class_attribute :raise_on_missing_callback_actions, instance_predicate: false, default: false
    end

    class ActionFilter # :nodoc:
      def initialize(filters, conditional_key, actions)
        @filters = filters.to_a
        @conditional_key = conditional_key
        @actions = Array(actions).map(&:to_s).to_set
      end

      def match?(controller)
        if controller.raise_on_missing_callback_actions
          missing_action = @actions.find { |action| !controller.available_action?(action) }
          if missing_action
            filter_names = @filters.length == 1 ? @filters.first.inspect : @filters.inspect

            message = <<~MSG
              The #{missing_action} action could not be found for the #{filter_names}
              callback on #{controller.class.name}, but it is listed in the controller's
              #{@conditional_key.inspect} option.

              Raising for missing callback actions is a new default in Rails 7.1, if you'd
              like to turn this off you can delete the option from the environment configurations
              or set `config.action_controller.raise_on_missing_callback_actions` to `false`.
            MSG

            raise ActionNotFound.new(message, controller, missing_action)
          end
        end

        @actions.include?(controller.action_name)
      end

      alias after  match?
      alias before match?
      alias around match?
    end

    module ClassMethods
      # If `:only` or `:except` are used, convert the options into the `:if` and
      # `:unless` options of ActiveSupport::Callbacks.
      #
      # The basic idea is that `:only => :index` gets converted to `:if => proc {|c|
      # c.action_name == "index" }`.
      #
      # Note that `:only` has priority over `:if` in case they are used together.
      #
      #     only: :index, if: -> { true } # the :if option will be ignored.
      #
      # Note that `:if` has priority over `:except` in case they are used together.
      #
      #     except: :index, if: -> { true } # the :except option will be ignored.
      #
      # #### Options
      # *   `only`   - The callback should be run only for this action.
      # *   `except`  - The callback should be run for all actions except this action.
      #
      def _normalize_callback_options(options)
        _normalize_callback_option(options, :only, :if)
        _normalize_callback_option(options, :except, :unless)
      end

      def _normalize_callback_option(options, from, to) # :nodoc:
        if from_value = options.delete(from)
          filters = options[:filters]
          from_value = ActionFilter.new(filters, from, from_value)
          options[to] = Array(options[to]).unshift(from_value)
        end
      end

      # Take callback names and an optional callback proc, normalize them, then call
      # the block with each callback. This allows us to abstract the normalization
      # across several methods that use it.
      #
      # #### Parameters
      # *   `callbacks` - An array of callbacks, with an optional options hash as the
      #     last parameter.
      # *   `block`    - A proc that should be added to the callbacks.
      #
      #
      # #### Block Parameters
      # *   `name`     - The callback to be added.
      # *   `options`  - A hash of options to be used when adding the callback.
      #
      def _insert_callbacks(callbacks, block = nil)
        options = callbacks.extract_options!
        callbacks.push(block) if block
        options[:filters] = callbacks
        _normalize_callback_options(options)
        options.delete(:filters)
        callbacks.each do |callback|
          yield callback, options
        end
      end

      ##
      # :method: before_action
      #
      # :call-seq: before_action(names, block)
      #
      # Append a callback before actions. See _insert_callbacks for parameter details.
      #
      # If the callback renders or redirects, the action will not run. If there are
      # additional callbacks scheduled to run after that callback, they are also
      # cancelled.

      ##
      # :method: prepend_before_action
      #
      # :call-seq: prepend_before_action(names, block)
      #
      # Prepend a callback before actions. See _insert_callbacks for parameter
      # details.
      #
      # If the callback renders or redirects, the action will not run. If there are
      # additional callbacks scheduled to run after that callback, they are also
      # cancelled.

      ##
      # :method: outermost_before_action
      #
      # :call-seq: outermost_before_action(names, block)
      #
      # Append a callback that is kept furthest from the action: every regular
      # `before_action`, including the ones prepended later on by subclasses, runs
      # after it. See _insert_callbacks for parameter details.
      #
      # `prepend_before_action` puts a callback in front of the callbacks registered
      # so far, but it cannot stay there, since the next `prepend_before_action`
      # wins. Use this for the callback that establishes the context every other
      # callback relies on, such as the tenant a request belongs to. It does not
      # have to be the only one: several of them keep the order they were
      # registered in, and a subclass registering its own lands after it, so this
      # one stays the first to run.
      #
      #     class ApplicationController < ActionController::Base
      #       outermost_before_action :set_current_tenant
      #
      #       private
      #         def set_current_tenant
      #           Current.tenant = Tenant.find_by!(host: request.host)
      #         end
      #     end
      #
      #     module Authentication
      #       extend ActiveSupport::Concern
      #
      #       included do
      #         # Needs Current.tenant, and has to run before everything else.
      #         prepend_before_action :authenticate
      #       end
      #     end
      #
      # The concern keeps working the way it was written, no matter which
      # controller includes it or in which order.
      #
      # If the callback renders or redirects, the action will not run. If there are
      # additional callbacks scheduled to run after that callback, they are also
      # cancelled.
      #
      # Shorthand for `before_action names, outermost: true`.

      ##
      # :method: skip_before_action
      #
      # :call-seq: skip_before_action(names)
      #
      # Skip a callback before actions. See _insert_callbacks for parameter details.

      ##
      # :method: append_before_action
      #
      # :call-seq: append_before_action(names, block)
      #
      # Append a callback before actions. See _insert_callbacks for parameter details.
      #
      # If the callback renders or redirects, the action will not run. If there are
      # additional callbacks scheduled to run after that callback, they are also
      # cancelled.

      ##
      # :method: innermost_before_action
      #
      # :call-seq: innermost_before_action(names, block)
      #
      # Append a callback that is kept closest to the action: every regular
      # `before_action`, including the ones registered later on by subclasses,
      # runs before it. See _insert_callbacks for parameter details.
      #
      # Callbacks otherwise run from the base controller down, which makes it
      # impossible for a base controller to act on a record its subclasses load.
      # This is what authorization, canonical redirects, breadcrumbs, or conditional
      # GET support in a base controller usually need:
      #
      #     class ApplicationController < ActionController::Base
      #       innermost_before_action :authorize_record, only: %i[ show edit update destroy ]
      #       innermost_before_action :set_cache_headers, only: :show
      #
      #       private
      #         def authorize_record
      #           head :forbidden unless Current.user.can?(action_name, @record)
      #         end
      #
      #         def set_cache_headers
      #           fresh_when(@record)
      #         end
      #     end
      #
      #     class ArticlesController < ApplicationController
      #       before_action :set_record # runs before :authorize_record
      #     end
      #
      # Without it, every subclass has to remember to re-register the inherited
      # callback after its own, which is easy to get wrong and impossible to
      # enforce.
      #
      # If the callback renders or redirects, the action will not run. If there are
      # additional callbacks scheduled to run after that callback, they are also
      # cancelled.
      #
      # Shorthand for `before_action names, innermost: true`.

      ##
      # :method: after_action
      #
      # :call-seq: after_action(names, block)
      #
      # Append a callback after actions. See _insert_callbacks for parameter details.

      ##
      # :method: prepend_after_action
      #
      # :call-seq: prepend_after_action(names, block)
      #
      # Prepend a callback after actions. See _insert_callbacks for parameter details.

      ##
      # :method: outermost_after_action
      #
      # :call-seq: outermost_after_action(names, block)
      #
      # Append a callback that is kept furthest from the action: every regular
      # `after_action`, including the ones prepended later on by subclasses, runs
      # before it, since `after_action` callbacks run in reverse order. See
      # _insert_callbacks for parameter details.
      #
      # Useful to tear down what an `outermost_before_action` set up, once every
      # other callback is done with it.
      #
      #     class ApplicationController < ActionController::Base
      #       outermost_before_action :set_current_tenant
      #       outermost_after_action :reset_current_tenant
      #     end
      #
      # Shorthand for `after_action names, outermost: true`.

      ##
      # :method: skip_after_action
      #
      # :call-seq: skip_after_action(names)
      #
      # Skip a callback after actions. See _insert_callbacks for parameter details.

      ##
      # :method: append_after_action
      #
      # :call-seq: append_after_action(names, block)
      #
      # Append a callback after actions. See _insert_callbacks for parameter details.

      ##
      # :method: innermost_after_action
      #
      # :call-seq: innermost_after_action(names, block)
      #
      # Append a callback that is kept closest to the action: every regular
      # `after_action`, including the ones registered later on by subclasses, runs
      # after it, since `after_action` callbacks run in reverse order. See
      # _insert_callbacks for parameter details.
      #
      # Useful to capture what the action did before any subclass gets a chance to
      # alter it.
      #
      #     class ApplicationController < ActionController::Base
      #       innermost_after_action :record_audit_entry, only: %i[ create update destroy ]
      #     end
      #
      # Shorthand for `after_action names, innermost: true`.

      ##
      # :method: around_action
      #
      # :call-seq: around_action(names, block)
      #
      # Append a callback around actions. See _insert_callbacks for parameter details.

      ##
      # :method: prepend_around_action
      #
      # :call-seq: prepend_around_action(names, block)
      #
      # Prepend a callback around actions. See _insert_callbacks for parameter
      # details.

      ##
      # :method: outermost_around_action
      #
      # :call-seq: outermost_around_action(names, block)
      #
      # Append a callback that is kept furthest from the action: every regular
      # `around_action`, including the ones prepended later on by subclasses, is
      # wrapped by it. See _insert_callbacks for parameter details.
      #
      # It observes everything that the callbacks registered after it do,
      # including what they raise, render, or redirect, which is what request-wide
      # instrumentation and error reporting need:
      #
      #     class ApplicationController < ActionController::Base
      #       outermost_around_action :report_errors
      #
      #       private
      #         def report_errors
      #           yield
      #         rescue => error
      #           ErrorReporter.report(error, context: { action: action_name })
      #           raise
      #         end
      #     end
      #
      # Shorthand for `around_action names, outermost: true`.

      ##
      # :method: skip_around_action
      #
      # :call-seq: skip_around_action(names)
      #
      # Skip a callback around actions. See _insert_callbacks for parameter details.

      ##
      # :method: append_around_action
      #
      # :call-seq: append_around_action(names, block)
      #
      # Append a callback around actions. See _insert_callbacks for parameter details.

      ##
      # :method: innermost_around_action
      #
      # :call-seq: innermost_around_action(names, block)
      #
      # Append a callback that is kept closest to the action: every regular
      # `around_action`, including the ones registered later on by subclasses,
      # wraps it. See _insert_callbacks for parameter details.
      #
      # Useful when the callback has to wrap the action alone, with no other
      # callback inside it: measuring how long the action itself takes, or opening
      # a transaction only once the records the action needs are loaded and
      # authorized.
      #
      #     class ApplicationController < ActionController::Base
      #       innermost_around_action :wrap_in_transaction, only: %i[ create update destroy ]
      #
      #       private
      #         def wrap_in_transaction(&block)
      #           ApplicationRecord.transaction(&block)
      #         end
      #     end
      #
      # Shorthand for `around_action names, innermost: true`.

      # set up before_action, prepend_before_action, skip_before_action, etc. for each
      # of before, after, and around.
      [:before, :after, :around].each do |callback|
        define_method "#{callback}_action" do |*names, &blk|
          _insert_callbacks(names, blk) do |name, options|
            set_callback(:process_action, callback, name, options)
          end
        end

        define_method "prepend_#{callback}_action" do |*names, &blk|
          _insert_callbacks(names, blk) do |name, options|
            set_callback(:process_action, callback, name, options.merge(prepend: true))
          end
        end

        define_method "outermost_#{callback}_action" do |*names, &blk|
          _insert_callbacks(names, blk) do |name, options|
            set_callback(:process_action, callback, name, options.merge(outermost: true))
          end
        end

        define_method "innermost_#{callback}_action" do |*names, &blk|
          _insert_callbacks(names, blk) do |name, options|
            set_callback(:process_action, callback, name, options.merge(innermost: true))
          end
        end

        # Skip a before, after or around callback. See _insert_callbacks for details on
        # the allowed parameters.
        define_method "skip_#{callback}_action" do |*names|
          _insert_callbacks(names) do |name, options|
            skip_callback(:process_action, callback, name, options)
          end
        end

        # *_action is the same as append_*_action
        alias_method :"append_#{callback}_action", :"#{callback}_action"
      end

      def internal_methods # :nodoc:
        super.concat(DEFAULT_INTERNAL_METHODS)
      end
    end

    private
      # Override `AbstractController::Base#process_action` to run the `process_action`
      # callbacks around the normal behavior.
      def process_action(...)
        run_callbacks(:process_action) do
          super
        end
      end
  end
end
