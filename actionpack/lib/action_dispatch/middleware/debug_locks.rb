# frozen_string_literal: true

module ActionDispatch
  # This middleware can be used to diagnose deadlocks in the autoload interlock.
  #
  # To use it, insert it near the top of the middleware stack, using
  # <tt>config/application.rb</tt>:
  #
  #     config.middleware.insert_before Rack::Sendfile, ActionDispatch::DebugLocks
  #
  # After restarting the application and re-triggering the deadlock condition,
  # <tt>/rails/locks</tt> will show a summary of all threads currently known to
  # the interlock, which lock level they are holding or awaiting, and their
  # current backtrace.
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
        path = req.path_info.chomp("/".freeze)
        if path == @path
          return render_details(req)
        end
      end

      @app.call(env)
    end

    private
      def render_details(_req)
        threads = ActiveSupport::Dependencies.interlock.raw_state do |raw_threads|
          # The Interlock itself comes to a complete halt as long as this block
          # is executing. That gives us a more consistent picture of everything,
          # but creates a pretty strong Observer Effect.
          #
          # Most directly, that means we need to do as little as possible in
          # this block. More widely, it means this middleware should remain a
          # strictly diagnostic tool (to be used when something has gone wrong),
          # and not for any sort of general monitoring.

          raw_threads.each.with_index do |(thread, info), idx|
            info[:index] = idx
            info[:backtrace] = thread.backtrace
          end

          raw_threads
        end

        str = threads.map do |thread, info|
          if info[:exclusive]
            lock_state = "Exclusive".dup
          elsif info[:sharing] > 0
            lock_state = "Sharing".dup
            lock_state << " x#{info[:sharing]}" if info[:sharing] > 1
          else
            lock_state = "No lock".dup
          end

          if info[:waiting]
            lock_state << " (yielded share)"
          end

          msg = "Thread #{info[:index]} [0x#{thread.__id__.to_s(16)} #{thread.status || 'dead'}]  #{lock_state}\n".dup

          if info[:sleeper]
            msg << "  Waiting in #{info[:sleeper]}"
            msg << " to #{info[:purpose].to_s.inspect}" unless info[:purpose].nil?
            msg << "\n"

            if info[:compatible]
              compat = info[:compatible].map { |c| c == false ? "share" : c.to_s.inspect }
              msg << "  may be pre-empted for: #{compat.join(', ')}\n"
            end

            blockers = threads.values.select { |binfo| blocked_by?(info, binfo, threads.values) }
            msg << "  blocked by: #{blockers.map { |i| i[:index] }.join(', ')}\n" if blockers.any?
          end

          blockees = threads.values.select { |binfo| blocked_by?(binfo, info, threads.values) }
          msg << "  blocking: #{blockees.map { |i| i[:index] }.join(', ')}\n" if blockees.any?

          msg << "\n#{info[:backtrace].join("\n")}\n" if info[:backtrace]
        end.join("\n\n---\n\n\n")

        [200, { "Content-Type" => "text/plain", "Content-Length" => str.size }, [str]]
      end

      def blocked_by?(victim, blocker, all_threads)
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
            all_threads.all? { |other| !other[:compatible] || blocker.equal?(other) || other[:compatible].include?(blocker[:purpose]) }
        end
      end
  end
end
