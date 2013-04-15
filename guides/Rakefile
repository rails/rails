namespace :guides do

  desc 'Generate guides (for authors), use ONLY=foo to process just "foo.md"'
  task :generate => 'generate:html'

  namespace :generate do

    desc "Generate HTML guides"
    task :html do
      ENV["WARN_BROKEN_LINKS"] = "1" # authors can't disable this
      ruby "rails_guides.rb"
    end

    desc "Generate .mobi file. The kindlegen executable must be in your PATH. You can get it for free from http://www.amazon.com/kindlepublishing"
    task :kindle do
      unless `kindlerb -v 2> /dev/null` =~ /kindlerb 0.1.1/  
        abort "Please `gem install kindlerb`"
      end
      unless `convert` =~ /convert/  
        abort "Please install ImageMagick`"
      end
      ENV['KINDLE'] = '1'
      Rake::Task['guides:generate:html'].invoke
    end
  end

  # Validate guides -------------------------------------------------------------------------
  desc 'Validate guides, use ONLY=foo to process just "foo.html"'
  task :validate do
    ruby "w3c_validator.rb"
  end

  desc "Show help"
  task :help do
    puts <<-help

Guides are taken from the source directory, and the resulting HTML goes into the
output directory. Assets are stored under files, and copied to output/files as
part of the generation process.

All this process is handled via rake tasks, here's a full list of them:

#{%x[rake -T]}
Some arguments may be passed via environment variables:

  WARNINGS=1
    Internal links (anchors) are checked, also detects duplicated IDs.

  ALL=1
    Force generation of all guides.

  ONLY=name
    Useful if you want to generate only one or a set of guides.

    Generate only association_basics.html:
      ONLY=assoc

    Separate many using commas:
      ONLY=assoc,migrations

  GUIDES_LANGUAGE
    Use it when you want to generate translated guides in
    source/<GUIDES_LANGUAGE> folder (such as source/es)

  EDGE=1
    Indicate generated guides should be marked as edge.

Examples:
  $ rake guides:generate ALL=1
  $ rake guides:generate EDGE=1
  $ rake guides:generate:kindle EDGE=1
  $ rake guides:generate GUIDES_LANGUAGE=es
    help
  end
end

task :default => 'guides:help'
