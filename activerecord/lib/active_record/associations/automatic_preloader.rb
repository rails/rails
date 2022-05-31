# frozen_string_literal: true

module ActiveRecord
  module Associations
    class AutomaticPreloader < Preloader
      def self.attach(records)
        new(records: records.dup, associations: nil).tap do |automatic_preloader|
          records.each do |record|
            record.automatic_preloader = automatic_preloader
          end
        end
      end

      def automatically_preload(associations)
        # It is possible that the records array has multiple different classes (think single table inheritance).
        # Thus, it is possible that some of the records don't have an association.
        records_with_association = records.reject do |record|
          record.class.reflect_on_association(associations).nil?
        end
        self.class.new(records: records_with_association, associations: associations).call
      end

      # We do not want the automatic preloader to be dumpable
      # If you dump a ActiveRecord::Base object that has an automatic_preloader instance variable
      # you will also end up dumping all of the records the preloader has reference to.
      # Imagine getting N objects from a query and dumping each one of those into a cache
      # each object would dump N+1 objects which means you'll end up storing O(N^2) memory. That's no good.
      # So instead, we will just nullify the automatic preloader on load
      def _dump(level)
        ""
      end

      def self._load(args)
        nil
      end
    end
  end
end
