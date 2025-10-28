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
  # *   `prepend_after_action`
  # *   `prepend_around_action`
  # *   `prepend_before_action`
  # *   `skip_after_action`
  # *   `skip_around_action`
  # *   `skip_before_action`
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
      mattr_accessor :raise_on_missing_callback_actions, default: false
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
