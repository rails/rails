module ActiveRecord
  module Explain # :nodoc:
    # logging_query_plan calls could appear nested in the call stack. In
    # particular this happens when a relation fetches its records, since
    # that results in find_by_sql calls downwards.
    #
    # This flag allows nested calls to detect this situation and bypass
    # it, thus preventing repeated EXPLAINs.
    LOGGING_QUERY_PLAN = :logging_query_plan

    # If auto explain is enabled, this method triggers EXPLAIN logging for the
    # queries triggered by the block if it takes more than the threshold as a
    # whole. That is, the threshold is not checked against each individual
    # query, but against the duration of the entire block. This approach is
    # convenient for relations.
    def logging_query_plan(&block)
      if (t = auto_explain_threshold_in_seconds) && !Thread.current[LOGGING_QUERY_PLAN]
        begin
          Thread.current[LOGGING_QUERY_PLAN] = true
          start = Time.now
          result, sqls, binds = collecting_sqls_for_explain(&block)
          logger.warn(exec_explain(sqls, binds)) if Time.now - start > t
          result
        ensure
          Thread.current[LOGGING_QUERY_PLAN] = false
        end
      else
        block.call
      end
    end

    # SCHEMA queries cannot be EXPLAINed, also we do not want to run EXPLAIN on
    # our own EXPLAINs now matter how loopingly beautiful that would be.
    SKIP_EXPLAIN_FOR = %w(SCHEMA EXPLAIN)
    def ignore_explain_notification?(payload)
      payload[:exception] || SKIP_EXPLAIN_FOR.include?(payload[:name])
    end

    # Collects all queries executed while the passed block runs. Returns an
    # array with three elements, the result of the block, the strings with the
    # queries, and their respective bindings.
    def collecting_sqls_for_explain(&block)
      sqls  = []
      binds = []
      callback = lambda do |*args|
        payload = args.last
        unless ignore_explain_notification?(payload)
          sqls  << payload[:sql]
          binds << payload[:binds]
        end
      end

      result = nil
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        result = block.call
      end

      [result, sqls, binds]
    end

    # Makes the adapter execute EXPLAIN for the given queries and bindings.
    # Returns a formatted string ready to be logged.
    def exec_explain(sqls, binds)
      sqls.zip(binds).map do |sql, bind|
        [].tap do |msg|
          msg << "EXPLAIN for: #{sql}"
          unless bind.empty?
            bind_msg = bind.map {|col, val| [col.name, val]}.inspect
            msg.last << " #{bind_msg}"
          end
          msg << connection.explain(sql, bind)
        end.join("\n")
      end.join("\n")
    end
  end
end
