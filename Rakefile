task default: %w[test]

task :test do
  ruby "-Ilib -e 'ARGV.each { |f| require f }' ./tests/test*.rb"
end
