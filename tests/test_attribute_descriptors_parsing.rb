require_relative 'bootstrap'


class TestAttributeDescriptorsParsing < Test::Unit::TestCase


  #
  # IMPORTANT: Pay attention when you use single quotes and when double quotes
  #            in the tests. Any YAML examples holding regexes MUST be quoted
  #            as string literals and not mistakenly be evaluated.
  #

  test 'parsing simple attribute descriptions in YAML' do
    yaml = "field1:\n  require: true"
    assert AttributeDescriptors.load_yaml(yaml)['field1']['require'] == true
  end

  test 'regular expressions are parsed as regular expressions' do
    yaml = "field1:\n  valid_values:\n   - /\\w/"
    parsed = AttributeDescriptors.load_yaml(yaml)
    assert parsed['field1']['valid_values'][:regexes].size == 1
    assert parsed['field1']['valid_values'][:regexes].first.is_a? Regexp
  end

  test 'regular expressions once parsed, have the \A and \z placeholders enforced' do
    yaml = "field1:\n  valid_values:\n   - /\\w/"
    parsed = AttributeDescriptors.load_yaml(yaml)
    assert parsed['field1']['valid_values'][:regexes].first == /\A\w\z/
  end

  test 'more advanced regexes should be parsed in the same way' do
    base = "field1:\n  valid_values:\n   - "
    regexes = {
      '/.*/' => /\A.*\z/,
      '/\w/' => /\A\w\z/,
      '/\w{10}/' => /\A\w{10}\z/,
      '/\w{10}[^\d]/' => /\A\w{10}[^\d]\z/,
    }
    regexes.each do |re_in, re_out|
      parsed = AttributeDescriptors.load_yaml(base + re_in)
      assert parsed['field1']['valid_values'][:regexes].first == re_out
    end
  end



  # ------------------------------- Load a file --------------------------------

  metadata_example = '''
Fieldname1:
  programmatic_name: name1
  require: true
Fieldname2:
  programmatic_name: name2
  require: true
Fieldname3:
  programmatic_name: name3
  require: false'''

  metadata_example_file = Tempfile.new('')
  metadata_example_file.write(metadata_example)
  metadata_example_file.close


  test 'generates a structure that uses the programmatic names as keys' do
    f = metadata_example_file
    parsed = AttributeDescriptors.load_file(f.path)
    YAML.load_file(f.path).each do |k,v|
      assert parsed.include? v['programmatic_name']
    end
  end

  test 'the structure should have a description for every attribute' do
    f = metadata_example_file
    parsed = AttributeDescriptors.load_file(f.path)
    YAML.load_file(f.path).each do |k,v|
      programmatic_name = v['programmatic_name']
      assert !parsed[programmatic_name]['description'].nil?
    end
  end

  test 'generates a structure that includes all values explicitly specified as they were given' do
    f = metadata_example_file
    parsed = AttributeDescriptors.load_file(f.path)
    assert parsed['name1']['programmatic_name'] == 'name1'
    assert parsed['name1']['require'] == true
    assert parsed['name2']['programmatic_name'] == 'name2'
    assert parsed['name2']['require'] == true
  end

  test 'forces validation regular expressions to be quoted (".*") or ruby-like (/.*/)' do
    assert true
  end

end
