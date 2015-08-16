require 'rails/commands/command'

module Rails
  module Commands
    class Notes < Command
      rake_delegate 'notes', 'notes:custom'

      set_banner :notes,
        'Enumerate all annotations (use notes:optimize, :fixme, :todo for focus)'
      set_banner :notes_custom, 
        'Enumerate a custom annotation, specify with ANNOTATION=CUSTOM'
    end
  end
end
