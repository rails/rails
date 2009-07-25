require "active_support/new_callbacks"

module AbstractController
  module Callbacks
    extend ActiveSupport::Concern

    # Uses ActiveSupport::NewCallbacks as the base functionality. For
    # more details on the whole callback system, read the documentation
    # for ActiveSupport::NewCallbacks.
    include ActiveSupport::NewCallbacks

    included do
      define_callbacks :process_action, "response_body"
    end

    # Override AbstractController::Base's process_action to run the
    # process_action callbacks around the normal behavior.
    def process_action(method_name)
      _run_process_action_callbacks(method_name) do
        super
      end
    end

    module ClassMethods
      # If :only or :accept are used, convert the options into the
      # primitive form (:per_key) used by ActiveSupport::Callbacks.
      # The basic idea is that :only => :index gets converted to
      # :if => proc {|c| c.action_name == "index" }, but that the
      # proc is only evaluated once per action for the lifetime of
      # a Rails process.
      #
      # ==== Options
      # :only<#to_s>:: The callback should be run only for this action
      # :except<#to_s>:: The callback should be run for all actions
      #   except this action
      def _normalize_callback_options(options)
        if only = options[:only]
          only = Array(only).map {|o| "action_name == '#{o}'"}.join(" || ")
          options[:per_key] = {:if => only}
        end
        if except = options[:except]
          except = Array(except).map {|e| "action_name == '#{e}'"}.join(" || ")
          options[:per_key] = {:unless => except}
        end
      end

      # Skip before, after, and around filters matching any of the names
      #
      # ==== Parameters
      # *names<Object>:: A list of valid names that could be used for
      #   callbacks. Note that skipping uses Ruby equality, so it's
      #   impossible to skip a callback defined using an anonymous proc
      #   using #skip_filter
      def skip_filter(*names, &blk)
        skip_before_filter(*names)
        skip_after_filter(*names)
        skip_around_filter(*names)
      end

      # Take callback names and an optional callback proc, normalize them,
      # then call the block with each callback. This allows us to abstract
      # the normalization across several methods that use it.
      #
      # ==== Parameters
      # callbacks<Array[*Object, Hash]>:: A list of callbacks, with an optional
      #   options hash as the last parameter.
      # block<Proc>:: A proc that should be added to the callbacks.
      #
      # ==== Block Parameters
      # name<Symbol>:: The callback to be added
      # options<Hash>:: A list of options to be used when adding the callback
      def _insert_callbacks(callbacks, block)
        options = callbacks.last.is_a?(Hash) ? callbacks.pop : {}
        _normalize_callback_options(options)
        callbacks.push(block) if block
        callbacks.each do |callback|
          yield callback, options
        end
      end

      # set up before_filter, prepend_before_filter, skip_before_filter, etc.
      # for each of before, after, and around.
      [:before, :after, :around].each do |filter|
        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          # Append a before, after or around filter. See _insert_callbacks
          # for details on the allowed parameters.
          def #{filter}_filter(*names, &blk)
            _insert_callbacks(names, blk) do |name, options|
              set_callback(:process_action, :#{filter}, name, options)
            end
          end

          # Prepend a before, after or around filter. See _insert_callbacks
          # for details on the allowed parameters.
          def prepend_#{filter}_filter(*names, &blk)
            _insert_callbacks(names, blk) do |name, options|
              set_callback(:process_action, :#{filter}, name, options.merge(:prepend => true))
            end
          end

          # Skip a before, after or around filter. See _insert_callbacks
          # for details on the allowed parameters.
          def skip_#{filter}_filter(*names, &blk)
            _insert_callbacks(names, blk) do |name, options|
              skip_callback(:process_action, :#{filter}, name, options)
            end
          end

          # *_filter is the same as append_*_filter
          alias_method :append_#{filter}_filter, :#{filter}_filter
        RUBY_EVAL
      end
    end
  end
end
