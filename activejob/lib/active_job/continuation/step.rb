# frozen_string_literal: true

module ActiveJob
  class Continuation
    # = Active Job Continuation Step
    #
    # Represents a step within a continuable job.
    #
    # When a step is completed, it is recorded in the job's continuation state.
    # If the job is interrupted, it will be resumed from after the last completed step.
    #
    # Steps also have an optional cursor that can be used to track progress within the step.
    # If a job is interrupted during a step, the cursor will be saved and passed back when
    # the job is resumed.
    #
    # It is the responsibility of the code in the step to use the cursor correctly to resume
    # from where it left off.
    class Step
      # The name of the step.
      attr_reader :name

      # The cursor for the step.
      attr_reader :cursor

      def initialize(name, cursor, resumed:, &checkpoint_callback)
        @name = name.to_sym
        @initial_cursor = cursor
        @cursor = cursor
        @resumed = resumed
        @checkpoint_callback = checkpoint_callback
      end

      # Check if the job should be interrupted, and if so raise an Interrupt exception.
      # The job will be requeued for retry.
      def checkpoint!
        checkpoint_callback.call
      end

      # Set the cursor and interrupt the job if necessary.
      def set!(cursor)
        @cursor = cursor
        checkpoint!
      end

      # Advance the cursor from the current or supplied value
      #
      # The cursor will be advanced by calling the +succ+ method on the cursor.
      # An UnadvanceableCursorError error will be raised if the cursor does not implement +succ+.
      def advance!(from: nil)
        from = cursor if from.nil?
        raise UnadvanceableCursorError, "Cursor class '#{from.class}' does not implement succ, " unless from.respond_to?(:succ)
        set! from.succ
      end

      # Has this step been resumed from a previous job execution?
      def resumed?
        @resumed
      end

      # Has the cursor been advanced during this job execution?
      def advanced?
        initial_cursor != cursor
      end

      def to_a
        [ name.to_s, cursor ]
      end

      def description
        "at '#{name}', cursor '#{cursor.inspect}'"
      end

      private
        attr_reader :checkpoint_callback, :initial_cursor
    end
  end
end
