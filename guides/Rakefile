namespace :guides do

  desc 'Generate guides (for authors), use ONLY=foo to process just "foo.textile"'
  task :generate => 'generate:html'

  namespace :generate do

    desc "Generate HTML guides"
    task :html do
      ENV["WARN_BROKEN_LINKS"] = "1" # authors can't disable this
      ruby "rails_guides.rb"
    end

    desc "Generate .mobi file"
    task :kindle do
      ENV['KINDLE'] = '1'
      Rake::Task['guides:generate:html'].invoke
    end
  end

  # Validate guides -------------------------------------------------------------------------
  desc 'Validate guides, use ONLY=foo to process just "foo.html"'
  task :validate do
    ruby "w3c_validator.rb"
  end

end
