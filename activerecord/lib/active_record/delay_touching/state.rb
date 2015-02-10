module ActiveRecord
  # = Active Record Delay Touching
  module DelayTouching

    # Tracking of the touch state. This class has no class-level data, so you can
    # store per-thread instances in thread-local variables.
    class State # :nodoc:
      def initialize
        @records = Hash.new { SortedSet.new }
        @already_touched_records = Hash.new { SortedSet.new }
      end

      def touched(klass, attrs, records)
        @already_touched_records[[klass, attrs]] += records
      end

      # Return the records grouped by class and columns that were touched:
      #
      #   {
      #     [Owner, [:updated_at]]               => SortedSet.new([owner1, owner2]),
      #     [Pet,   [:neutered_at, :updated_at]] => SortedSet.new([pet1]),
      #     [Pet,   [:updated_at]]               => SortedSet.new([pet2])
      #   }
      #
      # As a side-effect, clears out the list of records.
      def get_and_clear_records
        records = @records
        @records = Hash.new { SortedSet.new }
        records
      end

      def more_records?
        @records.present?
      end

      def add_record(record, columns)
        # Include the standard updated_at column and any additional specified columns
        columns += record.timestamp_attributes_for_update_in_model
        columns = columns.map(&:to_sym).sort

        key = [record.class, columns]
        @records[key] += [record] unless @already_touched_records[key].include?(record)
      end

      def clear_already_touched_records
        @already_touched_records.clear
      end

      # Merge another state into this one
      def merge!(other_state)
        merge_records!(@records, other_state.records)
        merge_records!(@already_touched_records, other_state.already_touched_records)
      end

      protected
        attr_reader :records, :already_touched_records

        # Merge from_records into into_records
        def merge_records!(into_records, from_records)
          from_records.each do |key, records|
            into_records[key] += records
          end
        end
    end
  end
end
