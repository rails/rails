# frozen_string_literal: true

# :markup: markdown

module ActiveJob
  # # Active Job Debouncing
  #
  # Provides a class macro for debouncing job enqueues. A burst of
  # `perform_later` calls collapses into at most two jobs per window: a leading
  # job that runs immediately and a trailing job that sweeps up whatever
  # happened during the window. Callers just enqueue at will.
  #
  #     class BadgeCountPushJob < ApplicationJob
  #       debounce within: 30.seconds, by: ->(user) { user.id }
  #
  #       def perform(user)
  #         user.push_badge_count
  #       end
  #     end
  module Debouncing
    extend ActiveSupport::Concern

    # Default claim store, backed by `Rails.cache.write(..., unless_exist: true)`.
    # A `nil` write result — an outage, on stores that can signal one, like
    # RedisCacheStore's failsafe — stays `nil`, so debouncing fails open.
    # Stores that can't tell an outage apart from a lost claim report a lost
    # claim, and suppress instead.
    module CacheStore
      extend self

      def claim(key, expires_in:)
        result = Rails.cache.write(key, true, unless_exist: true, expires_in: expires_in)
        !!result unless result.nil?
      end
    end

    included do
      class_attribute :debounce_options, instance_accessor: false, default: nil
      class_attribute :debounce_store, instance_writer: false, default: CacheStore
    end

    module ClassMethods
      # Debounces enqueues of this job class. Bursts of `perform_later` calls
      # within the window of time given by `within:` collapse into a leading
      # job, enqueued immediately, and a trailing job, scheduled a full window
      # after the first coalesced call. Further calls within the window are
      # suppressed: their enqueue is aborted and `perform_later` returns
      # `false`. (Enqueues deferred until transaction commit decide at commit
      # time instead, so their `perform_later` returns the job either way.)
      #
      # Enqueues are debounced per the identity given by `by:` — a callable
      # evaluated in the context of the job and passed the job's arguments, or
      # a method name (as a symbol) called on the job. If the result responds
      # to `cache_key`, its value is used as the key; otherwise `to_param` is.
      # Without `by:`, the whole class shares one debounce.
      #
      # `leading: false` turns off the immediate leading edge: the first call
      # is itself scheduled a full window out, a classic trailing debounce, and
      # further calls are suppressed — the scheduled job sweeps them up.
      # `trailing: false` turns off the trailing sweep: calls after the leading
      # enqueue are suppressed until the window expires.
      #
      # Claims live in `store:`, any object responding to
      # `claim(key, expires_in:)` and returning `true` when the claim is won,
      # `false` when it was already claimed, or `nil` when the store is
      # unavailable — in which case debouncing fails open and the job enqueues
      # immediately. Defaults to `debounce_store` (CacheStore over
      # Rails.cache), resolved at enqueue time. Claim keys are scoped by
      # `scope:`, defaulting to the underscored class name.
      #
      # Jobs enqueued with an explicit `set(wait:)`/`set(wait_until:)` bypass
      # debouncing, as do retries: they always enqueue.
      #
      # Every decision emits a `debounce.active_job` notification with the
      # job, the claim key, and the outcome: `:leading`, `:trailing`,
      # `:suppressed`, or `:failed_open`.
      def debounce(within:, by: nil, leading: true, trailing: true, store: nil, scope: nil)
        raise ArgumentError, "debounce is already declared on #{self}" if debounce_options
        raise ArgumentError, "debounce requires a leading or trailing edge" unless leading || trailing

        self.debounce_options = { within: within, by: by, leading: leading, trailing: trailing, store: store, scope: scope || to_s.underscore }
        before_enqueue :debounce_enqueue
      end
    end

    private
      def debounce_enqueue
        if scheduled_at.nil? && executions.zero?
          options = self.class.debounce_options
          phase, key, claim = claim_debounce(options)

          if claim == false
            ActiveSupport::Notifications.instrument "debounce.active_job", job: self, key: key, outcome: :suppressed
            logger.debug "Suppressed debounced #{self.class} enqueue: #{key}"
            throw :abort
          else
            if phase == :trailing || (claim && !options[:leading])
              self.scheduled_at = options[:within].from_now
            end

            ActiveSupport::Notifications.instrument "debounce.active_job", job: self, key: key, outcome: debounce_outcome(phase, claim)
          end
        end
      end

      def claim_debounce(options)
        store = options[:store] || self.class.debounce_store
        by = debounce_by(options)

        phase = :leading
        key = debounce_key(phase, by, options)
        claim = store.claim(key, expires_in: options[:within])

        if claim == false && options[:leading] && options[:trailing]
          phase = :trailing
          key = debounce_key(phase, by, options)
          claim = store.claim(key, expires_in: options[:within])
        end

        [ phase, key, claim ]
      end

      def debounce_by(options)
        case by = options[:by]
        when nil
          nil
        when Symbol
          debounce_key_component send(by)
        else
          debounce_key_component instance_exec(*arguments, &by)
        end
      end

      def debounce_key_component(value)
        if value.respond_to?(:cache_key)
          value.cache_key
        else
          value.to_param
        end
      end

      def debounce_key(phase, by, options)
        [ "debounce", options[:scope], by, phase ].compact.join(":")
      end

      def debounce_outcome(phase, claim)
        if claim.nil?
          :failed_open
        else
          phase
        end
      end
  end
end
