desc "Generate documentation for the application"
Rake::RDocTask.new("appdoc") { |rdoc|
  rdoc.rdoc_dir = 'doc/app'
  rdoc.title    = "Rails Application Documentation"
  rdoc.options << '--line-numbers --inline-source'
  rdoc.rdoc_files.include('doc/README_FOR_APP')
  rdoc.rdoc_files.include('app/**/*.rb')
}

desc "Generate documentation for the Rails framework"
Rake::RDocTask.new("apidoc") { |rdoc|
  rdoc.rdoc_dir = 'doc/api'
  rdoc.template = "#{ENV['template']}.rb" if ENV['template']
  rdoc.title    = "Rails Framework Documentation"
  rdoc.options << '--line-numbers --inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/railties/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/railties/MIT-LICENSE')
  rdoc.rdoc_files.include('vendor/rails/activerecord/README')
  rdoc.rdoc_files.include('vendor/rails/activerecord/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/activerecord/lib/active_record/**/*.rb')
  rdoc.rdoc_files.exclude('vendor/rails/activerecord/lib/active_record/vendor/*')
  rdoc.rdoc_files.include('vendor/rails/actionpack/README')
  rdoc.rdoc_files.include('vendor/rails/actionpack/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/actionpack/lib/action_controller/**/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionpack/lib/action_view/**/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionmailer/README')
  rdoc.rdoc_files.include('vendor/rails/actionmailer/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/actionmailer/lib/action_mailer/base.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/README')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/api/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/client/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/container/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/dispatcher/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/protocol/*.rb')
  rdoc.rdoc_files.include('vendor/rails/actionwebservice/lib/action_web_service/support/*.rb')
  rdoc.rdoc_files.include('vendor/rails/activesupport/README')
  rdoc.rdoc_files.include('vendor/rails/activesupport/CHANGELOG')
  rdoc.rdoc_files.include('vendor/rails/activesupport/lib/active_support/**/*.rb')
}