require_relative '../attribute_descriptors'

require 'rspec/core'
require 'test/unit' # Needed for assertion methods
require 'stringio'
require 'yaml'
require 'awesome_print'

#
# EXAMPLE 1
#
metadata_example = '''Fieldname1:
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

#
# EXAMPLE 2
#
# REMOVE THIS!!!!!!!!!!!!!!!! UNUSED GARBAGE!!!!
#
metadata_example2_file = Tempfile.new('dsfasdfasgfdhshs ')



describe AttributeDescriptors do
  include Test::Unit::Assertions

  describe 'load_yaml' do
    #
    # IMPORTANT: Pay attention when you use single quotes and when double quotes
    #            in the tests. Any YAML examples holding regexes MUST be quoted
    #            as string literals and not mistakenly be evaluated.
    #
    it 'can be parsed in its most simple form' do
      yaml = "field1:\n  require: true"
      assert AttributeDescriptors.load_yaml(yaml)['field1']['require'] == true
    end

    it 'can take the more compact syntax "a=1 b=2" etc.' do
      yaml = "field1: require=true example=jojo\n  whatever=bleh"
      parsed = AttributeDescriptors.load_yaml(yaml)
      assert parsed['field1']['require'] = true
      assert parsed['field1']['example'] = 'jojo'
      assert parsed['field1']['whatever'] = 'bleh'
    end

    it 's "validate" entries become regular expressions after being parsed' do
      yaml = 'field1: validate=\w'
      assert AttributeDescriptors.load_yaml(yaml)['field1']['validate'].is_a? Regexp
    end

    it 's "validate" entries once parsed, have the \A and \z placeholders enforced' do
      yaml = 'field1: validate=\w'
      assert AttributeDescriptors.load_yaml(yaml)['field1']['validate'] == /\A\w\z/
    end

    it 's "validate" regexes can also use the ruby syntax (/bleh/)' do
      yaml = 'field1: validate=/\w/'
      assert AttributeDescriptors.load_yaml(yaml)['field1']['validate'] == /\A\w\z/
    end

    it 'more advanced regexes should be parsed in the same way' do
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
  end




  describe 'load_file' do

    it 'generates a structure that uses the programmatic names as keys' do
      f = metadata_example_file
      parsed = AttributeDescriptors.load_file(f.path)
      YAML.load_file(f.path).each do |k,v|
        assert parsed.include? v['programmatic_name']
      end
    end

    it 'the structure should have a description for every attribute' do
      f = metadata_example_file
      parsed = AttributeDescriptors.load_file(f.path)
      YAML.load_file(f.path).each do |k,v|
        programmatic_name = v['programmatic_name']
        assert !parsed[programmatic_name]['description'].nil?
      end
    end

    it 'generates a structure that includes all values explicitly specified as they were given' do
      f = metadata_example_file
      parsed = AttributeDescriptors.load_file(f.path)
      assert parsed['name1']['programmatic_name'] == 'name1'
      assert parsed['name1']['require'] == true
      assert parsed['name2']['programmatic_name'] == 'name2'
      assert parsed['name2']['require'] == true
    end

    it 'forces validation regular expressions to be quoted (".*") or ruby-like (/.*/)' do
      assert true
    end

  end



  #############################################
  #
  #            AutogeneratedModel
  #
  #############################################
  describe 'a model based on metadata' do
    METADATA_PATH  = metadata_example_file.path
    METADATA2_PATH = metadata_example2_file.path
    class MyModel < AttributeDescriptors::AutogeneratedModel
      generated_from METADATA_PATH
    end

    it 'gives a unique instance on initialization (no singletons or caches)' do
      assert MyModel.new != MyModel.new
    end

    it 'let\s you read the metadata but not overwrite it'  do
      m = MyModel.new
      assert m.public_methods.include? :metadata
      assert m.metadata.class == Hash
      assert ! m.public_methods.include?(:metadata=)
    end

    it 'has attributes generated automatically based on the metadata' do
      m = MyModel.new
      fieldname = m.metadata.first[0]
      attribute = m.metadata[fieldname]['programmatic_name']
      assert m.public_methods.include? "#{attribute}".to_sym
      assert m.public_methods.include? "#{attribute}=".to_sym
    end

    it 'sets attributes passed on initialization' do
      attrs = {'name1' => 'jojo', 'name2' => 'coco', 'nonexistentattr' => 'test'}
      m = MyModel.new(attrs)
      assert m.name1 == 'jojo'
      assert m.name2 == 'coco'
      expect { m.nonexistentattr }.to raise_error NoMethodError
    end

    it 'doesnt require attributes on initialization' do
      m = MyModel.new
      assert m.name1 == nil
      assert m.name2 == nil
    end




    #############################################
    #
    #               Validations
    #
    #############################################
    describe 'generated validations' do

      it 'generates ActiveModel validations' do
        assert MyModel.public_methods.include? :validate
      end

      it 'has validations that work even when no attributes are passed on initialization' do
        m = MyModel.new
        assert ! m.valid?
        assert m.errors.include? 'name1'.to_sym
        assert m.errors.include? 'name2'.to_sym
      end

      it 'ActiveModel edge-case' do
        #
        # ActiveModel seems to require valid? to be invoked in order
        # for the errors to be generated. We add this test just to be aware in
        # case this behaviour changes.
        #
        assert ! MyModel.new().valid? # Should always work
        # Revoking before invalid?
        m = MyModel.new()
        assert m.errors.size == 0
        assert ! m.valid?
        assert m.errors.size > 0
      end

      it 'doesnt give any error when a non-required parameter is omitted' do
        attrs = {'name1' => 'jojo', 'name2' => 'coco'}
        m = MyModel.new(attrs)
        assert m.valid?
      end

      it 'invalidates when a parameter required is not passed' do
        m = MyModel.new
        assert ! m.valid?
        assert m.errors.include? 'name1'.to_sym
        assert m.errors.include? 'name2'.to_sym
      end

      it 'can catch "blank field" errors' do
        m = MyModel.new
        assert ! m.valid?
        assert m.errors['name1'][0] == "can't be blank"
        assert m.errors['name2'][0] == "can't be blank"
      end


    end

  end


end
