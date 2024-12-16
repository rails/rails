# frozen_string_literal: true

require "active_support/hash_with_indifferent_access"

# = Active Storage \Blob \Analyzable
module ActiveStorage::Blob::Analyzable
  # Extracts and stores metadata from the file associated with this blob using relevant analyzers. Active Storage comes
  # with built-in analyzers for images and videos. See ActiveStorage::Analyzer::ImageAnalyzer and
  # ActiveStorage::Analyzer::VideoAnalyzer for information about the specific attributes they extract and the third-party
  # libraries they require.
  #
  # To choose the analyzer for a blob, Active Storage calls +accept?+ on each registered analyzer in order. It uses
  # all analyzers for which +accept?+ returns true when given the blob. If no registered analyzer accepts the blob, no
  # metadata is extracted from it.
  #
  # In a \Rails application, add or remove analyzers by manipulating +Rails.application.config.active_storage.analyzers+
  # in an initializer:
  #
  #   # Add a custom analyzer for Microsoft Office documents:
  #   Rails.application.config.active_storage.analyzers.append DOCXAnalyzer
  #
  #   # Remove the built-in video analyzer:
  #   Rails.application.config.active_storage.analyzers.delete ActiveStorage::Analyzer::VideoAnalyzer
  #
  # Outside of a \Rails application, manipulate +ActiveStorage.analyzers+ instead.
  #
  # You won't ordinarily need to call this method from a \Rails application. New blobs are automatically and asynchronously
  # analyzed via #analyze_later when they're attached for the first time.
  def analyze
    update! metadata: metadata.merge(extract_metadata_via_analyzer)
  end

  # Enqueues an ActiveStorage::AnalyzeJob which calls #analyze, or calls #analyze inline based on analyzer class configuration.
  #
  # This method is automatically called for a blob when it's attached for the first time. You can call it to analyze a blob
  # again (e.g. if you add a new analyzer or modify an existing one).
  def analyze_later
    if analyzer_classes.any?(&:analyze_later?)
      ActiveStorage::AnalyzeJob.perform_later(self)
    else
      analyze
    end
  end

  # Returns true if the blob has been analyzed.
  def analyzed?
    analyzed
  end

  private
    def extract_metadata_via_analyzer
      analyzers.reduce(ActiveSupport::HashWithIndifferentAccess.new) do |metadata, analyzer|
        metadata.deep_merge!(analyzer.metadata)
      end.merge!(analyzed: true)
    end

    def analyzers
      analyzer_classes.map { |analyzer_class| analyzer_class.new(self) }
    end

    def analyzer_classes
      ActiveStorage.analyzers.select { |klass| klass.accept?(self) }
    end
end
