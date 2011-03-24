class PluginBuilder < Rails::PluginBuilder
  def gitignore
    create_file ".gitignore", <<-R.strip
foobar
    R
  end
end
