# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  # # Action Dispatch DebugLocks
  #
  # This middleware can be used to diagnose deadlocks in the autoload interlock.
  #
  # To use it, insert it near the top of the middleware stack, using
  # `config/application.rb`:
  #
  #     config.middleware.insert_before ActionDispatch::Executor, ActionDispatch::DebugLocks
  #
  # After restarting the application and re-triggering the deadlock condition, the
  # route `/rails/locks` will show a summary of all execution contexts (threads
  # or fibers, depending on `config.active_support.isolation_level`) currently
  # known to the interlock, which lock level they are holding or awaiting, and
  # their current backtrace.
  #
  # Generally a deadlock will be caused by the interlock conflicting with some
  # other external lock or blocking I/O call. These cannot be automatically
  # identified, but should be visible in the displayed backtraces.
  #
  # NOTE: The formatting and content of this middleware's output is intended for
  # human consumption, and should be expected to change between releases.
  #
  # This middleware exposes operational details of the server, with no access
  # control. It should only be enabled when in use, and removed thereafter.
  class DebugLocks
    def initialize(app, path = "/rails/locks")
      @app = app
      @path = path
    end

    def call(env)
      req = ActionDispatch::Request.new env

      if req.get?
        path = req.path_info.chomp("/")
        if path == @path
          return render_details(req)
        end
      end

      @app.call(env)
    end

    private
      def render_details(req)
        owners = ActiveSupport::Dependencies.interlock.raw_state do |raw_owners|
          # The Interlock itself comes to a complete halt as long as this block is
          # executing. That gives us a more consistent picture of everything, but creates
          # a pretty strong Observer Effect.
          #
          # Most directly, that means we need to do as little as possible in this block.
          # More widely, it means this middleware should remain a strictly diagnostic tool
          # (to be used when something has gone wrong), and not for any sort of general
          # monitoring.

          raw_owners.each.with_index do |(owner, info), idx|
            info[:index] = idx
            info[:backtrace] = owner.backtrace
          end

          raw_owners
        end

        str = owners.map do |owner, info|
          if info[:exclusive]
            lock_state = +"Exclusive"
          elsif info[:sharing] > 0
            lock_state = +"Sharing"
            lock_state << " x#{info[:sharing]}" if info[:sharing] > 1
          else
            lock_state = +"No lock"
          end

          if info[:waiting]
            lock_state << " (yielded share)"
          end

          msg = +"#{owner.class} #{info[:index]} [0x#{owner.__id__.to_s(16)} #{owner_status(owner)}]  #{lock_state}\n"

          if info[:sleeper]
            msg << "  Waiting in #{info[:sleeper]}"
            msg << " to #{info[:purpose].to_s.inspect}" unless info[:purpose].nil?
            msg << "\n"

            if info[:compatible]
              compat = info[:compatible].map { |c| c == false ? "share" : c.to_s.inspect }
              msg << "  may be pre-empted for: #{compat.join(', ')}\n"
            end

            blockers = owners.values.select { |binfo| blocked_by?(info, binfo, owners.values) }
            msg << "  blocked by: #{blockers.map { |i| i[:index] }.join(', ')}\n" if blockers.any?
          end

          blockees = owners.values.select { |binfo| blocked_by?(binfo, info, owners.values) }
          msg << "  blocking: #{blockees.map { |i| i[:index] }.join(', ')}\n" if blockees.any?

          msg << "\n#{info[:backtrace].join("\n")}\n" if info[:backtrace]
        end.join("\n\n---\n\n\n")

        [200, { Rack::CONTENT_TYPE => "text/plain; charset=#{ActionDispatch::Response.default_charset}",
                Rack::CONTENT_LENGTH => str.size.to_s }, [str]]
      end

      def owner_status(owner)
        case owner
        when Thread then owner.status || "dead"
        when Fiber then owner.alive? ? "alive" : "dead"
        end
      end

      def blocked_by?(victim, blocker, all_owners)
        return false if victim.equal?(blocker)

        case victim[:sleeper]
        when :start_sharing
          blocker[:exclusive] ||
            (!victim[:waiting] && blocker[:compatible] && !blocker[:compatible].include?(false))
        when :start_exclusive
          blocker[:sharing] > 0 ||
            blocker[:exclusive] ||
            (blocker[:compatible] && !blocker[:compatible].include?(victim[:purpose]))
        when :yield_shares
          blocker[:exclusive]
        when :stop_exclusive
          blocker[:exclusive] ||
            victim[:compatible] &&
            victim[:compatible].include?(blocker[:purpose]) &&
            all_owners.all? { |other| !other[:compatible] || blocker.equal?(other) || other[:compatible].include?(blocker[:purpose]) }
        end
      end
  end
end
