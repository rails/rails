module ActiveRecord
  module Encryption
    # Encrypts all the models belonging to the provided list of classes
    class MassEncryption
      attr_reader :classes, :last_class, :last_id, :progress_monitor, :skip_rich_texts

      def initialize(progress_monitor: NullProgressMonitor.new, last_class: nil, last_id: nil, skip_rich_texts: false)
        @progress_monitor = progress_monitor
        @last_class = last_class
        @last_id = last_id
        @classes = []
        @skip_rich_texts = skip_rich_texts

        raise ArgumentError, "When passing a :last_id you must pass a :last_class too" if last_id.present? && last_class.blank?
      end

      def add(*classes)
        @classes.push(*classes)
        progress_monitor.total = calculate_total
        self
      end

      def encrypt
        included_classes.each.with_index do |klass, index|
          ClassMassEncryption.new(klass, progress_monitor: progress_monitor, last_id: last_id, skip_rich_texts: skip_rich_texts).encrypt
        end
      end

      private
        def calculate_total
          total = sum_all(classes) - sum_all(excluded_classes)
          total -= last_class.where("id < ?", last_id) if last_id.present?
          total
        end

        def sum_all(classes)
          classes.sum { |klass| klass.count }
        end

        def included_classes
          classes - excluded_classes
        end

        def excluded_classes
          if last_class
            last_class_index = classes.find_index(last_class)
            classes.find_all.with_index do |_, index|
              index >= last_class_index
            end
          else
            []
          end
        end
    end

    class ClassMassEncryption
      attr_reader :klass, :progress_monitor, :last_id, :skip_rich_texts

      def initialize(klass, progress_monitor: NullEncryptor.new, last_id: nil, skip_rich_texts: false)
        @klass = klass
        @progress_monitor = progress_monitor
        @last_id = last_id
        @skip_rich_texts = skip_rich_texts
      end

      def encrypt
        klass.where("id >= ?", last_id.to_i).find_each.with_index do |record, index|
          encrypt_record(record)
          progress_monitor.increment
          progress_monitor.log("Encrypting #{klass.name.tableize} (last id = #{record.id})...") if index % 500 == 0
        end
      end

      private
        def encrypt_record(record)
          record.encrypt(skip_rich_texts: skip_rich_texts)
        rescue
          logger.error("Error when encrypting #{record.class} record with id #{record.id}")
          raise
        end

        def logger
          Rails.logger
        end
    end

    class NullProgressMonitor
      def increment
      end

      def total=(new_value) end

      def log(text)
        puts text
      end
    end
  end
end
