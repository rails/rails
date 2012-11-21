require 'active_support/lazy_load_hooks'

module ActiveRecord
  module Explain
    def self.extended(base)
      base.mattr_accessor :auto_explain_threshold_in_seconds, instance_accessor: false
    end

    # If the database adapter supports explain and auto explain is enabled,
    # this method triggers EXPLAIN logging for the queries triggered by the
    # block if it takes more than the threshold as a whole. That is, the
    # threshold is not checked against each individual query, but against the
    # duration of the entire block. This approach is convenient for relations.

    #
    # The available_queries_for_explain thread variable collects the queries
    # to be explained. If the value is nil, it means queries are not being
    # currently collected. A false value indicates collecting is turned
    # off. Otherwise it is an array of queries.
    def logging_query_plan # :nodoc:
      return yield unless logger

      threshold = auto_explain_threshold_in_seconds
      current   = Thread.current
      if connection.supports_explain? && threshold && current[:available_queries_for_explain].nil?
        begin
          queries = current[:available_queries_for_explain] = []
          start = Time.now
          result = yield
          logger.warn(exec_explain(queries)) if Time.now - start > threshold
          result
        ensure
          current[:available_queries_for_explain] = nil
        end
      else
        yield
      end
    end

    # Relation#explain needs to be able to collect the queries regardless of
    # whether auto explain is enabled. This method serves that purpose.
    def collecting_queries_for_explain # :nodoc:
      current = Thread.current
      original, current[:available_queries_for_explain] = current[:available_queries_for_explain], []
      return yield, current[:available_queries_for_explain]
    ensure
      # Note that the return value above does not depend on this assigment.
      current[:available_queries_for_explain] = original
    end

    # Makes the adapter execute EXPLAIN for the tuples of queries and bindings.
    # Returns a formatted string ready to be logged.
    def exec_explain(queries) # :nodoc:
      str = queries && queries.map do |sql, bind|
        [].tap do |msg|
          msg << "EXPLAIN for: #{sql}"
          unless bind.empty?
            bind_msg = bind.map {|col, val| [col.name, val]}.inspect
            msg.last << " #{bind_msg}"
          end
          msg << connection.explain(sql, bind)
        end.join("\n")
      end.join("\n")

      # Overriding inspect to be more human readable, specially in the console.
      def str.inspect
        self
      end
      str
    end

    # Silences automatic EXPLAIN logging for the duration of the block.
    #
    # This has high priority, no EXPLAINs will be run even if downwards
    # the threshold is set to 0.
    #
    # As the name of the method suggests this only applies to automatic
    # EXPLAINs, manual calls to <tt>ActiveRecord::Relation#explain</tt> run.
    def silence_auto_explain
      current = Thread.current
      original, current[:available_queries_for_explain] = current[:available_queries_for_explain], false
      yield
    ensure
      current[:available_queries_for_explain] = original
    end
  end
end
