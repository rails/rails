name: Ruby Gem

on:
  pull_request:
    branches:
      - master
  push:
    branches:
      - master

jobs:
  build:
    name: Build + Publish
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@master
    - name: Set up Ruby 2.6
      uses: actions/setup-ruby@v1
      with:
        version: 2.6.x

    - name: Publish to GPR
      run: |
        mkdir -p $HOME/.gem
        touch $HOME/.gem/credentials
        chmod 0600 $HOME/.gem/credentials
        printf -- "---\n:github: Bearer ${GEM_HOST_API_KEY}\n" > $HOME/.gem/credentials
        gem build *.gemspec
        gem push --KEY github --host https://rubygems.pkg.github.com/${OWNER} *.gem
      env:
        GEM_HOST_API_KEY: ${{secrets.GPR_AUTH_TOKEN}}
        OWNER: username

    - name: Publish to RubyGems
      run: |
        mkdir -p $HOME/.gem
        touch $HOME/.gem/credentials
        chmod 0600 $HOME/.gem/credentials
        printf -- "---\n:rubygems_api_key: ${GEM_HOST_API_KEY}\n" > $HOME/.gem/credentials
        gem build *.gemspec
        gem push *.gem
      env:
        GEM_HOST_API_KEY: ${{secrets.RUBYGEMS_AUTH_TOKEN}}
