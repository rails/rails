FRAMEWORKS = %w( activesupport activemodel activerecord activeresource actionpack actionmailer railties )

root    = File.expand_path('../../', __FILE__)
version = File.read("#{root}/RAILS_VERSION").strip

directory "dist"

(FRAMEWORKS + ['rails']).each do |framework|
  namespace framework do
    gem     = "dist/#{framework}-#{version}.gem"
    gemspec = "#{framework}.gemspec"

    task :clean do
      rm_f gem
    end

    task :update_version_rb do
      glob = root.dup
      glob << "/#{framework}/lib/*" unless framework == "rails"
      glob << "/version.rb"

      file = Dir[glob].first
      ruby = File.read(file)

      major, minor, tiny, pre = version.split('.')
      pre ||= "nil"

      ruby.gsub! /^(\s*)MAJOR = .*?$/, "\\1MAJOR = #{major}"
      raise "Could not insert MAJOR in #{file}" unless $1

      ruby.gsub! /^(\s*)MINOR = .*?$/, "\\1MINOR = #{minor}"
      raise "Could not insert MINOR in #{file}" unless $1

      ruby.gsub! /^(\s*)TINY  = .*?$/, "\\1TINY  = #{tiny}"
      raise "Could not insert TINY in #{file}" unless $1

      ruby.gsub! /^(\s*)PRE   = .*?$/, "\\1PRE   = #{pre}"
      raise "Could not insert PRE in #{file}" unless $1

      File.open(file, 'w') { |f| f.write ruby }
    end

    task gem => %w(update_version_rb dist) do
      cmd = ""
      cmd << "cd #{framework} && " unless framework == "rails"
      cmd << "gem build #{gemspec} && mv #{framework}-#{version}.gem #{root}/dist/"
      sh cmd
    end

    task :build => [:clean, gem]
    task :install => :build do
      sh "gem install #{gem}"
    end

    task :push => :build do
      sh "gem push #{gem}"
    end
  end
end

namespace :git do
  task :tag do
    sh "git tag v#{version}"
  end
end

namespace :all do
  task :build   => FRAMEWORKS.map { |f| "#{f}:build"   } + ['rails:build']
  task :install => FRAMEWORKS.map { |f| "#{f}:install" } + ['rails:install']
  task :push    => FRAMEWORKS.map { |f| "#{f}:push"    } + ['rails:push']
end

__END__
version = ARGV.pop

%w( activesupport activemodel activerecord activeresource actionpack actionmailer railties ).each do |framework|
  puts "Building and pushing #{framework}..."
  `cd #{framework} && gem build #{framework}.gemspec && gem push #{framework}-#{version}.gem && rm #{framework}-#{version}.gem`
end

puts "Building and pushing Rails..."
`gem build rails.gemspec`
`gem push rails-#{version}.gem`
`rm rails-#{version}.gem`

