
Run all tests

    ruby -Ilib -e 'ARGV.each { |f| require f }' ./tests/test*.rb


Run an individual test

    bundle exec ruby tests/test_attribute_descriptors_usage.rb
