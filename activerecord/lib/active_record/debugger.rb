module ActiveRecord
  module Debugger
    TEMPLATE_PATH = File.expand_path("../templates", __FILE__)

    def self.enabled=(value)
      ActiveSupport::IsolatedExecutionState[:active_record_debugging] = value
    end

    def self.enable_debugging
      raise ActiveRecord::LoadTree::LoadTreeDisabledError unless ActiveRecord.load_tree_enabled
      self.enabled = true
    end

    def self.disable_debugging
      self.enabled = false
    end

    def self.enabled?
      ActiveSupport::IsolatedExecutionState[:active_record_debugging] ||= false
    end

    # Mark an ActiveRecord instance/s as loaded.
    def self.add_loaded_records(records)
      return loaded_records unless self.enabled?
      return loaded_records if records.nil?
      records = Array(records) unless records.is_a?(Array)
      loaded_records.concat(records).uniq!
    end

    # All ActiveRecords instances marked as loaded.
    def self.loaded_records
      ActiveSupport::IsolatedExecutionState[:active_record_loaded_records] ||= []
    end

    # Reset the state of tracked loaded and used records.
    def self.clear_loaded_records
      ActiveSupport::IsolatedExecutionState[:active_record_loaded_records] = []
    end
  end
end