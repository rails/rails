say "Copying actiontext.scss to app/assets/stylesheets"
copy_file "#{__dir__}/actiontext.scss", "app/assets/stylesheets/actiontext.scss"

say "Copying fixtures to test/fixtures/action_text/rich_texts.yml"
copy_file "#{__dir__}/fixtures.yml", "test/fixtures/action_text/rich_texts.yml"

say "Copying blob rendering partial to app/views/active_storage/blobs/_blob.html.erb"
copy_file "#{__dir__}/../../app/views/active_storage/blobs/_blob.html.erb",
  "app/views/active_storage/blobs/_blob.html.erb"

say "Installing JavaScript dependency"
run "yarn add @rails/actiontext"

APPLICATION_PACK_PATH = "app/javascript/packs/application.js"

if File.exist?(APPLICATION_PACK_PATH) && File.read(APPLICATION_PACK_PATH) !~ /import "@rails\/actiontext"/
  say "Adding import to default JavaScript pack"
  append_to_file APPLICATION_PACK_PATH, <<-EOS
import "@rails/actiontext"
EOS
end
