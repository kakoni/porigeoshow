require 'test_helper'
require 'pori'

describe PoriScraper do
  it 'reads decissions and saves them into pdf' do
    VCR.use_cassette('decissions') do
      pori = PoriScraper.new
      results = pori.scrape
      results.wont_be_empty
      FileUtils.rm Dir.glob('*.pdf')
    end
  end
end
