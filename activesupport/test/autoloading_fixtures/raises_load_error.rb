# frozen_string_literal: true

# raises a load error typical of the dynamic code that manually raises load errors
raise LoadError, 'required gem not present kind of error'
