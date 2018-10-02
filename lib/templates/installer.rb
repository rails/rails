say "Copying actiontext.css to app/assets/stylesheets"
copy_file "#{__dir__}/actiontext.css", "app/assets/stylesheets/actiontext.css"

say "Copying fixtures to test/fixtures/action_text/rich_texts.yml"
copy_file "#{__dir__}/fixtures.yml", "test/fixtures/action_text/rich_texts.yml"

# FIXME: Replace with release version on release
say "Installing JavaScript dependency"
run "yarn add https://github.com/basecamp/actiontext"

APPLICATION_PATH_PATH = "app/javascript/packs/application.js"

if File.exists?(APPLICATION_PATH_PATH) && File.read(APPLICATION_PATH_PATH) !~ /import "actiontext"/
  say "Adding import to default JavaScript pack"
  append_to_file APPLICATION_PATH_PATH, <<-EOS
import "actiontext"
EOS
end
