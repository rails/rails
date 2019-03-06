# frozen_string_literal: true

require "rails/code_statistics"

class Rails::Conductor::NotesController < Rails::Conductor::BaseController
  def show
    @notes = extract_notes
  end

  private
    def extract_notes
      capture_stdout do
        Rails::SourceAnnotationExtractor.enumerate %w[ OPTIMIZE FIXME TODO ].join("|")
      end
    end

    def capture_stdout
      original_stdout, $stdout = $stdout, StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout
    end
  end
