module AbstractController
  module Callbacks
    extend ActiveSupport::Concern

    # Uses ActiveSupport::Callbacks as the base functionality. For
    # more details on the whole callback system, read the documentation
    # for ActiveSupport::Callbacks.
    include ActiveSupport::Callbacks

    included do
      define_callbacks :process_action,
                       terminator: ->(controller, result_lambda) { result_lambda.call if result_lambda.is_a?(Proc); controller.performed? },
                       skip_after_callbacks_if_terminated: true
    end

    # Override AbstractController::Base's process_action to run the
    # process_action callbacks around the normal behavior.
    def process_action(*args)
      run_callbacks(:process_action) do
        super
      end
    end

    module ClassMethods
      # If +:only+ or +:except+ are used, convert the options into the
      # +:if+ and +:unless+ options of ActiveSupport::Callbacks.
      #
      # The basic idea is that <tt>:only => :index</tt> gets converted to
      # <tt>:if => proc {|c| c.action_name == "index" }</tt>.
      #
      # Note that <tt>:only</tt> has priority over <tt>:if</tt> in case they
      # are used together.
      #
      #   only: :index, if: -> { true } # the :if option will be ignored.
      #
      # Note that <tt>:if</tt> has priority over <tt>:except</tt> in case they
      # are used together.
      #
      #   except: :index, if: -> { true } # the :except option will be ignored.
      #
      # ==== Options
      # * <tt>only</tt>   - The callback should be run only for this action.
      # * <tt>except</tt>  - The callback should be run for all actions except this action.
      def _normalize_callback_options(options)
        _normalize_callback_option(options, :only, :if)
        _normalize_callback_option(options, :except, :unless)
      end

      def _normalize_callback_option(options, from, to) # :nodoc:
        if from = options[from]
          _from = Array(from).map(&:to_s).to_set
          from = proc { |c| _from.include? c.action_name }
          options[to] = Array(options[to]).unshift(from)
        end
      end

      # Take callback names and an optional callback proc, normalize them,
      # then call the block with each callback. This allows us to abstract
      # the normalization across several methods that use it.
      #
      # ==== Parameters
      # * <tt>callbacks</tt> - An array of callbacks, with an optional
      #   options hash as the last parameter.
      # * <tt>block</tt>    - A proc that should be added to the callbacks.
      #
      # ==== Block Parameters
      # * <tt>name</tt>     - The callback to be added.
      # * <tt>options</tt>  - A hash of options to be used when adding the callback.
      def _insert_callbacks(callbacks, block = nil)
        options = callbacks.extract_options!
        _normalize_callback_options(options)
        callbacks.push(block) if block
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

      ##
      # :method: prepend_before_action
      #
      # :call-seq: prepend_before_action(names, block)
      #
      # Prepend a callback before actions. See _insert_callbacks for parameter details.

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
      # Prepend a callback around actions. See _insert_callbacks for parameter details.

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

      # set up before_action, prepend_before_action, skip_before_action, etc.
      # for each of before, after, and around.
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

        # Skip a before, after or around callback. See _insert_callbacks
        # for details on the allowed parameters.
        define_method "skip_#{callback}_action" do |*names|
          _insert_callbacks(names) do |name, options|
            skip_callback(:process_action, callback, name, options)
          end
        end

        # *_action is the same as append_*_action
        alias_method :"append_#{callback}_action", :"#{callback}_action"
      end
    end
  end
end
