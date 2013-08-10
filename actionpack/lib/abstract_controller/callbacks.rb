module AbstractController
  module Callbacks
    extend ActiveSupport::Concern

    # Uses ActiveSupport::Callbacks as the base functionality. For
    # more details on the whole callback system, read the documentation
    # for ActiveSupport::Callbacks.
    include ActiveSupport::Callbacks

    included do
      define_callbacks :process_action, :terminator => "response_body", :skip_after_callbacks_if_terminated => true
    end

    # Override AbstractController::Base's process_action to run the
    # process_action callbacks around the normal behavior.
    def process_action(*args)
      run_callbacks(:process_action) do
        super
      end
    end

    module ClassMethods
      # If :only or :except are used, convert the options into the
      # :unless and :if options of ActiveSupport::Callbacks.
      # The basic idea is that :only => :index gets converted to
      # :if => proc {|c| c.action_name == "index" }.
      #
      # ==== Options
      # * <tt>only</tt>   - The callback should be run only for this action
      # * <tt>except</tt>  - The callback should be run for all actions except this action
      def _normalize_callback_options(options)
        _normalize_callback_option(options, :only, :if)
        _normalize_callback_option(options, :except, :unless)
      end

      def _normalize_callback_option(options, from, to) # :nodoc:
        if from = options[from]
          from = Array(from).map {|o| "action_name == '#{o}'"}.join(" || ")
          options[to] = Array(options[to]).unshift(from)
        end
      end

      # Skip before, after, and around action callbacks matching any of the names
      # Aliased as skip_filter.
      #
      # ==== Parameters
      # * <tt>names</tt> - A list of valid names that could be used for
      #   callbacks. Note that skipping uses Ruby equality, so it's
      #   impossible to skip a callback defined using an anonymous proc
      #   using #skip_filter
      def skip_action_callback(*names)
        skip_before_action(*names)
        skip_after_action(*names)
        skip_around_action(*names)
      end

      alias_method :skip_filter, :skip_action_callback

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
      # * <tt>name</tt>     - The callback to be added
      # * <tt>options</tt>  - A hash of options to be used when adding the callback
      def _insert_callbacks(callbacks, block = nil)
        options = callbacks.last.is_a?(Hash) ? callbacks.pop : {}
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
      # Aliased as before_filter.

      ##
      # :method: prepend_before_action
      #
      # :call-seq: prepend_before_action(names, block)
      #
      # Prepend a callback before actions. See _insert_callbacks for parameter details.
      # Aliased as prepend_before_filter.

      ##
      # :method: skip_before_action
      #
      # :call-seq: skip_before_action(names)
      #
      # Skip a callback before actions. See _insert_callbacks for parameter details.
      # Aliased as skip_before_filter.

      ##
      # :method: append_before_action
      #
      # :call-seq: append_before_action(names, block)
      #
      # Append a callback before actions. See _insert_callbacks for parameter details.
      # Aliased as append_before_filter.

      ##
      # :method: after_action
      #
      # :call-seq: after_action(names, block)
      #
      # Append a callback after actions. See _insert_callbacks for parameter details.
      # Aliased as after_filter.

      ##
      # :method: prepend_after_action
      #
      # :call-seq: prepend_after_action(names, block)
      #
      # Prepend a callback after actions. See _insert_callbacks for parameter details.
      # Aliased as prepend_after_filter.

      ##
      # :method: skip_after_action
      #
      # :call-seq: skip_after_action(names)
      #
      # Skip a callback after actions. See _insert_callbacks for parameter details.
      # Aliased as skip_after_filter.

      ##
      # :method: append_after_action
      #
      # :call-seq: append_after_action(names, block)
      #
      # Append a callback after actions. See _insert_callbacks for parameter details.
      # Aliased as append_after_filter.

      ##
      # :method: around_action
      #
      # :call-seq: around_action(names, block)
      #
      # Append a callback around actions. See _insert_callbacks for parameter details.
      # Aliased as around_filter.

      ##
      # :method: prepend_around_action
      #
      # :call-seq: prepend_around_action(names, block)
      #
      # Prepend a callback around actions. See _insert_callbacks for parameter details.
      # Aliased as prepend_around_filter.

      ##
      # :method: skip_around_action
      #
      # :call-seq: skip_around_action(names)
      #
      # Skip a callback around actions. See _insert_callbacks for parameter details.
      # Aliased as skip_around_filter.

      ##
      # :method: append_around_action
      #
      # :call-seq: append_around_action(names, block)
      #
      # Append a callback around actions. See _insert_callbacks for parameter details.
      # Aliased as append_around_filter.

      # set up before_action, prepend_before_action, skip_before_action, etc.
      # for each of before, after, and around.
      [:before, :after, :around].each do |callback|
        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          # Append a before, after or around callback. See _insert_callbacks
          # for details on the allowed parameters.
          def #{callback}_action(*names, &blk)                                                    # def before_action(*names, &blk)
            _insert_callbacks(names, blk) do |name, options|                                      #   _insert_callbacks(names, blk) do |name, options|
              set_callback(:process_action, :#{callback}, name, options)                          #     set_callback(:process_action, :before, name, options)
            end                                                                                   #   end
          end                                                                                     # end

          alias_method :#{callback}_filter, :#{callback}_action

          # Prepend a before, after or around callback. See _insert_callbacks
          # for details on the allowed parameters.
          def prepend_#{callback}_action(*names, &blk)                                            # def prepend_before_action(*names, &blk)
            _insert_callbacks(names, blk) do |name, options|                                      #   _insert_callbacks(names, blk) do |name, options|
              set_callback(:process_action, :#{callback}, name, options.merge(:prepend => true))  #     set_callback(:process_action, :before, name, options.merge(:prepend => true))
            end                                                                                   #   end
          end                                                                                     # end

          alias_method :prepend_#{callback}_filter, :prepend_#{callback}_action

          # Skip a before, after or around callback. See _insert_callbacks
          # for details on the allowed parameters.
          def skip_#{callback}_action(*names)                                                     # def skip_before_action(*names)
            _insert_callbacks(names) do |name, options|                                           #   _insert_callbacks(names) do |name, options|
              skip_callback(:process_action, :#{callback}, name, options)                         #     skip_callback(:process_action, :before, name, options)
            end                                                                                   #   end
          end                                                                                     # end

          alias_method :skip_#{callback}_filter, :skip_#{callback}_action

          # *_action is the same as append_*_action
          alias_method :append_#{callback}_action, :#{callback}_action  # alias_method :append_before_action, :before_action
          alias_method :append_#{callback}_filter, :#{callback}_action  # alias_method :append_before_filter, :before_action
        RUBY_EVAL
      end
    end
  end
end
