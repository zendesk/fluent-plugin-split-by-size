require "helper"
require "fluent/plugin/filter_split_by_size.rb"

class SplitBySizeFilterTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  CONFIG = %[
    id_field hash_id
  ]

  def filter(config, messages)
    d = create_driver(config)
    d.run(default_tag: "input.access") do
      messages.each do |message|
        d.feed(message)
      end
    end
    d.filtered_records
  end

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::SplitBySizeFilter).configure(conf)
  end

  sub_test_case 'configured with invalid configuration' do
    test 'empty configuration' do
      assert_raise(Fluent::ConfigError) do
         create_driver('')
      end
    end
  end

  test 'small records go through untouched' do
    conf = CONFIG
    messages = [
      { "hash_id" => "123456789", "message" => "This is test message" }
    ]
    expected = [
      { "hash_id" => "123456789", "message" => "This is test message" }
    ]
    filtered_records = filter(conf, messages)
    assert_equal(expected, filtered_records)
  end

  test 'records are properly divided when too big' do
    conf = %[
      id_field hash_id
      max_event_size 250 # This allows for 50 characters in a record
    ]
    messages = [
      { "hash_id" => "123456789", "message" => "This is test message", 1 => "a", 2 => "b", 3 => "c", 4 => "d" }
    ]
    expected = [
      {"message"=>"This is test message", 2=>"b", 4=>"d", "hash_id"=>"123456789"},
      {1=>"a", 3=>"c", "hash_id"=>"123456789"}
    ]
    filtered_records = filter(conf, messages)
    assert_equal(expected, filtered_records)
  end

  test 'fields that are too large are dropped' do
    conf = %[
      id_field hash_id
      max_event_size 250 # This allows for 50 characters in a record
    ]
    messages = [
      { "hash_id" => "123456789", "message" => "This is test message", "big_field": "This field is larger thant the max allowable field size so it should be dropped." }
    ]
    expected = [
      {"message"=>"This is test message", "hash_id"=>"123456789"}
    ]
    filtered_records = filter(conf, messages)
    assert_equal(expected, filtered_records)
  end
end
