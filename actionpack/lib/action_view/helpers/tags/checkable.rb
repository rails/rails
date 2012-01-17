module ActionView
  module Helpers
    module Tags
      module Checkable
        def input_checked?(object, options)
          if options.has_key?("checked")
            checked = options.delete "checked"
            checked == true || checked == "checked"
          else
            checked?(value(object))
          end
        end
      end
    end
  end
end
