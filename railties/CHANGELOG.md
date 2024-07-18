*   Add sessions generator to give a basic start to an authentication system using database-tracked sessions.


    # Generate with...
    bin/rails generate sessions

    # Generated files
    app/models/current.rb
    app/models/user.rb
    app/models/session.rb
    app/controllers/sessions_controller.rb
    app/views/sessions/new.html.erb
    db/migrate/xxxxxxx_create_users.rb
    db/migrate/xxxxxxx_create_sessions.rb


    *DHH*


*   Add not-null type modifier to migration attributes.


    # Generating with...
    bin/rails generate migration CreateUsers email_address:string!:uniq password_digest:string!

    # Produces:
    class CreateUsers < ActiveRecord::Migration[8.0]
      def change
        create_table :users do |t|
          t.string :email_address, null: false
          t.string :password_digest, null: false

          t.timestamps
        end
        add_index :users, :email_address, unique: true
      end
    end


    *DHH*

*   Add script folder and generator

    Add a new script default folder to hold your one-off or general purpose
    scripts, such as data migration scripts, cleanup scripts, etc.

    A new script generator allows you to create such scripts:

      `rails generate script my_script`

    You can run the generated script using:

      `ruby script/my_script.rb`

    *Jerome Dalbert*, *Haroon Ahmed*

*   Enable tracking route source locations only when using routes command. Previously,
    it was enabled in development mode, but is only needed for `bin/rails routes -E`.

    *Gannon McGibbon*

*   Deprecate `bin/rake stats` in favor of `bin/rails stats`.

    *Juan Vásquez*

*   Add internal page `/rails/info/notes`, that displays the same information as `bin/rails notes`.

    *Deepak Mahakale*

*   Add Rubocop and GitHub Actions to plugin generator.
    This can be skipped using --skip-rubocop and --skip-ci.

    *Chris Oliver*

*   Use Kamal for deployment by default, which includes generating a Rails-specific config/deploy.yml.
    This can be skipped using --skip-kamal. See more: https://kamal-deploy.org/

    *DHH*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/railties/CHANGELOG.md) for previous changes.
