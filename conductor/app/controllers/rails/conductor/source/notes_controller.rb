# frozen_string_literal: true

class Rails::Conductor::Source::NotesController < Rails::Conductor::CommandController
  def show
    @notes = extract_notes
  end

  private
    def extract_notes
      capture_stdout { Rails::SourceAnnotationExtractor.enumerate tags_param }
    end

    def tags_param
      params[:tag].presence || %w[ OPTIMIZE FIXME TODO ].join("|")
    end
end
