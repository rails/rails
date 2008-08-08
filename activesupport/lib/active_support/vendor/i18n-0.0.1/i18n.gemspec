Gem::Specification.new do |s|
  s.name = "i18n"
  s.version = "0.0.1"
  s.date = "2008-06-13"
  s.summary = "Internationalization for Ruby"
  s.email = "rails-patch-i18n@googlegroups.com"
  s.homepage = "http://groups.google.com/group/rails-patch-i18n"
  s.description = "Add Internationalization to your Ruby application."
  s.has_rdoc = false
  s.authors = ['Sven Fuchs', 'Matt Aimonetti', 'Stephan Soller', 'Saimon Moore']
  s.files = [
    "lib/i18n/backend/minimal.rb",
    "lib/i18n/core_ext.rb",
    "lib/i18n/localization.rb",
    "lib/i18n/translation.rb",
    "lib/i18n.rb",
    "LICENSE",
    "README",
    "spec/core_ext_spec.rb",
    "spec/i18n_spec.rb",
    "spec/spec.opts",
    "spec/spec_helper.rb"
  ]
end