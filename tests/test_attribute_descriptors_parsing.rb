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

  test 'can take the more compact syntax "a=1 b=2" etc.' do
    yaml = "field1: require=true example=jojo\n  whatever=bleh"
    parsed = AttributeDescriptors.load_yaml(yaml)
    assert parsed['field1']['require'] = true
    assert parsed['field1']['example'] = 'jojo'
    assert parsed['field1']['whatever'] = 'bleh'
  end

  test 's "validate" entries become regular expressions after being parsed' do
    yaml = 'field1: validate=\w'
    assert AttributeDescriptors.load_yaml(yaml)['field1']['validate'].is_a? Regexp
  end

  test 's "validate" entries once parsed, have the \A and \z placeholders enforced' do
    yaml = 'field1: validate=\w'
    assert AttributeDescriptors.load_yaml(yaml)['field1']['validate'] == /\A\w\z/
  end

  test 's "validate" regexes can also use the ruby syntax (/bleh/)' do
    yaml = 'field1: validate=/\w/'
    assert AttributeDescriptors.load_yaml(yaml)['field1']['validate'] == /\A\w\z/
  end

  test 'more advanced regexes should be parsed in the same way' do
    base = "field1:\n  validate: "
    regexes = {
      '.*' => /\A.*\z/,
      '\w' => /\A\w\z/,
      '\w{10}' => /\A\w{10}\z/,
      '\w{10}[^\d]' => /\A\w{10}[^\d]\z/,
    }
    regexes.each do |re_in, re_out|
      assert AttributeDescriptors.load_yaml(base + re_in)['field1']['validate'] == re_out
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
  validates: \w{5}
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
