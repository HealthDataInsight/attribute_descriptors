
Vanilla testing
---------------

Run all tests

    ruby -Ilib -e 'ARGV.each { |f| require f }' ./tests/test*.rb


Run an individual test

    bundle exec ruby tests/test_attribute_descriptors_usage.rb


Rails multi-versions
--------------------

Test against all Rails versions

    appraisal rake test

Test against Rails 3

    appraisal rails-3 rake test

Test against Rails 4

    appraisal rails-4 rake test
