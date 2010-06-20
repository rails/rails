module Tests
  module Api
    autoload :Basics,        'api/tests/basics'
    autoload :Defaults,      'api/tests/defaults'
    autoload :Interpolation, 'api/tests/interpolation'
    autoload :Link,          'api/tests/link'
    autoload :Lookup,        'api/tests/lookup'
    autoload :Pluralization, 'api/tests/pluralization'
    autoload :Procs,         'api/tests/procs'

    module Localization
      autoload :Date,        'api/tests/localization/date'
      autoload :DateTime,    'api/tests/localization/date_time'
      autoload :Procs,       'api/tests/localization/procs'
      autoload :Time,        'api/tests/localization/time'
    end
  end
end