require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'vcr'
require 'byebug'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :webmock # or :fakeweb
end
