module ActiveRecord
  # = Active Record Delay Touching
  module DelayTouching

    # Tracking of the touch state. This class has no class-level data, so you can
    # store per-thread instances in thread-local variables.
    class State # :nodoc:
      def initialize
        @records = Hash.new { Set.new }
        @already_updated_records = Hash.new { Set.new }
      end

      def updated(klass, attrs, records)
        @already_updated_records[[klass, attrs]] += records
      end

      # Return the records grouped by class and columns that were touched:
      #
      #   {
      #     [Owner, [:updated_at]]               => [owner1, owner2],
      #     [Pet,   [:neutered_at, :updated_at]] => [pet1],
      #     [Pet,   [:updated_at]]               => [pet2]
      #   }
      #
      # As a side-effect, clears out the list of records.
      def get_and_clear_records
        records = @records
        @records = Hash.new { Set.new }
        records
      end

      def more_records?
        @records.present?
      end

      def add_record(record, columns)
        # Include the standard updated_at column and any additional specified columns
        updated_at_attrs = record.send(:timestamp_attributes_for_update_in_model)
        columns += updated_at_attrs if updated_at_attrs.present?
        columns = columns.sort

        @records[[record.class, columns]] += [record] unless @already_updated_records[[record.class, columns]].include?(record)
      end

      def clear_records
        @records.clear
      end

      def clear_already_updated_records
        @already_updated_records.clear
      end

      # Merge another state into this one
      def merge!(other_state)
        merge_records!(@records, other_state.records)
        merge_records!(@already_updated_records, other_state.already_updated_records)
      end

      protected

      attr_accessor :records, :already_updated_records

      # Merge from_records into into_records
      def merge_records!(into_records, from_records)
        from_records.each do |key, records|
          into_records[key] += records
        end
      end
    end
  end
end
