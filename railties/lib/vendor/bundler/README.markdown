## Bundler : A gem to bundle gems

    Github:       http://github.com/wycats/bundler
    Mailing list: http://groups.google.com/group/ruby-bundler
    IRC:          #carlhuda on freenode

## Intro

Bundler is a tool that manages gem dependencies for your ruby application. It
takes a gem manifest file and is able to fetch, download, and install the gems
and all child dependencies specified in this manifest. It can manage any update
to the gem manifest file and update the bundled gems accordingly. It also lets
you run any ruby code in context of the bundled gem environment.

## Disclaimer

This project is under rapid development. It is usable today, but there will be
many changes in the near future, including to the Gemfile DSL. We will bump up
versions with changes though. We greatly appreciate feedback.

## Installation

Bundler has no dependencies. Just clone the git repository and install the gem
with the following rake task:

    rake install

## Usage

Bundler requires a gem manifest file to be created. This should be a file named
`Gemfile` located in the root directory of your application. After the manifest
has been created, in your shell, cd into your application's directory and run
`gem bundle`. This will start the bundling process.

### Manifest file

This is where you specify all of your application's dependencies. By default
this should be in a file named `Gemfile` located in your application's root
directory. The following is an example of a potential `Gemfile`. For more
information, please refer to Bundler::ManifestBuilder.

    # Specify a dependency on rails. When the bundler downloads gems,
    # it will download rails as well as all of rails' dependencies (such as
    # activerecord, actionpack, etc...)
    #
    # At least one dependency must be specified
    gem "rails"

    # Specify a dependency on rack v.1.0.0. The version is optional. If present,
    # it can be specified the same way as with rubygems' #gem method.
    gem "rack", "1.0.0"

    # Specify a dependency rspec, but only activate that gem in the "testing"
    # environment (read more about environments later). :except is also a valid
    # option to specify environment restrictions.
    gem "rspec", :only => :testing

    # Add http://gems.github.com as a source that the bundler will use
    # to find gems listed in the manifest. By default,
    # http://gems.rubyforge.org is already added to the list.
    #
    # This is an optional setting.
    source "http://gems.github.com"

    # Specify where the bundled gems should be stashed. This directory will
    # be a gem repository where all gems are downloaded to and installed to.
    #
    # This is an optional setting.
    # The default is: vendor/gems
    bundle_path "my/bundled/gems"

    # Specify where gem executables should be copied to.
    #
    # This is an optional setting.
    # The default is: bin
    bin_path "my/executables"

    # Specify that rubygems should be completely disabled. This means that it
    # will be impossible to require it and that available gems will be
    # limited exclusively to gems that have been bundled.
    #
    # The default is to automatically require rubygems. There is also a
    # `disable_system_gems` option that will limit available rubygems to
    # the ones that have been bundled.
    disable_rubygems

### Running Bundler

Once a manifest file has been created, the only thing that needs to be done
is to run the `gem bundle` command anywhere in your application. The script
will load the manifest file, resole all the dependencies, download all
needed gems, and install them into the specified directory.

Every time an update is made to the manifest file, run `gem bundle` again to
get the changes installed. This will only check the remote sources if your
currently installed gems do not satisfy the `Gemfile`. If you want to force
checking for updates on the remote sources, use the `--update` option.

### Running your application

The easiest way to run your application is to start it with an executable
copied to the specified bin directory (by default, simply bin). For example,
if the application in question is a rack app, start it with `bin/rackup`.
This will automatically set the gem environment correctly.

Another way to run arbitrary ruby code in context of the bundled gems is to
run it with the `gem exec` command. For example:

    gem exec ruby my_ruby_script.rb

Yet another way is to manually require the environment file first. This is
located in `[bundle_path]/environments/default.rb`. For example:

    ruby -r vendor/gems/environment.rb my_ruby_script.rb

### Using Bundler with Rails today

It should be possible to use Bundler with Rails today. Here are the steps
to follow.

* In your rails app, create a Gemfile and specify the gems that your
  application depends on. Make sure to specify rails as well:

        gem "rails", "2.1.2"
        gem "will_paginate"

        # Optionally, you can disable system gems all together and only
        # use bundled gems.
        disable_system_gems

* Run `gem bundle`

* You can now use rails if you prepend `gem exec` to every call to `script/*`
  but that isn't fun.

* At the top of `config/boot.rb`, add the following line:

        require File.expand_path(File.join(File.dirname(__FILE__), '..', 'vendor', 'gems', 'environment'))

In theory, this should be enough to get going.

## To require rubygems or not

Ideally, no gem would assume the presence of rubygems at runtime. Rubygems provides
enough features so that this isn't necessary. However, there are a number of gems
that require specific rubygem features.

If the `disable_rubygems` option is used, Bundler will stub out the most common
of these features, but it is possible that things will not go as intended quite
yet. So, if you are brave, try your code without rubygems at runtime.

## Known Issues

* When a gem points to a git repository, the git repository will be cloned
  every time Bundler does a gem dependency resolve.

## Reporting bugs

Please report all bugs on the github issue tracker for the project located
at:

    http://github.com/wycats/bundler/issues/