unset BUNDLE_GEMFILE
bundle install
bundle exec ruby db_setup.rb
bundle exec rake
