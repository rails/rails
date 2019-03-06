# frozen_string_literal: true

require "rails/code_statistics"

class Rails::Conductor::NotesController < Rails::Conductor::CommandController
  def show
    @notes = extract_notes
  end

  private
    def extract_notes
      capture_stdout { Rails::SourceAnnotationExtractor.enumerate %w[ OPTIMIZE FIXME TODO ].join("|") }
    end
end
