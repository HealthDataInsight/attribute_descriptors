require_relative '../attribute_descriptors'

require 'rspec/core'
require 'test/unit'  # Needed for assertion methods
require 'stringio'
require 'yaml'
require 'awesome_print'

#
# EXAMPLE 1
# NOTICE: \A..\z denote the start and end of the string. ^..$ should not be used
#         for security reasons.
#
metadata = '''
Favorite animals:
  programmatic_name: fav_animals
  valid_num_values: 1
  valid_values:
    - snake
    - hippo
    - squirel
    - other
'''
metafile = Tempfile.new('')
metafile.write(metadata)
metafile.close



describe 'model with attribute favorite_vowers' do
  include Test::Unit::Assertions
  METADATA = AttributeDescriptors.load_file(metafile.path)
  METADATA_PATH  = metafile.path
  class MyModel
    extend AttributeDescriptors::ClassAttributes
    generated_from METADATA_PATH

    def initialize(attrs = {})
      # Set attributes
      attrs.each do |attr_name, value|
        send("#{attr_name}=", value) if self.class.attributes.include? attr_name
      end
    end
  end

  # it "limits valid values based on metadata" do
  #   m = MyModel.new({'fav_animals' => 'e'})
  #   assert m.valid?
  #   m = MyModel.new({'fav_animals' => 'g'})
  #   assert !m.valid?
  # end

  # it "invalidate an attribute if not exact numbers of values are given" do
  #   m = MyModel.new({'fav_animals' => ['a']})
  #   assert !m.valid?
  #   m = MyModel.new({'fav_animals' => ['a', 'e']})
  #   assert m.valid?
  #   m = MyModel.new({'fav_animals' => ['a', 'e', 'i']})
  #   assert !m.valid?
  # end

  # CURRENTLY ONLY WORKING WITH NON-ARRAY
  it "invalidate an attribute if it's not inside the permitted window of values" do
    m = MyModel.new({'fav_animals' => 'cat'})
    assert !m.valid?
    m = MyModel.new({'fav_animals' => 'hippo'})
    assert m.valid?
  end

end
