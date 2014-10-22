require 'pdf-reader'
require 'mechanize'
require 'csv'

class PermitWriter
  attr_reader :permits

  def initialize(permits)
    @permits = permits
  end

  def write_to_csv(filename)
    CSV.open(filename, 'w', col_sep: ';') do |csv|
      permits.each do |p|
        csv << [p.owner, p.property_id, p.address, p.reason, p.info]
      end
    end
  end
end

class Permit
  attr_reader :owner, :property_id, :address, :reason, :info

  def initialize(owner, property_id, address, reason, info)
    @owner = owner
    @property_id = property_id
    @address = address
    @reason = reason
    @info = info
  end

  def to_s
    puts "o: #{owner}, id: #{property_id}, a: #{address}, r: #{reason}, i: #{info}"
  end
end

class PoriScraper
  attr_reader :page, :agent

  def initialize(agent: Mechanize.new, url: 'http://kokoukset.pori.fi/ktwebbin/dbisa.dll/ktwebscr/epj_tek.htm')
    @agent = agent
    @page = @agent.get(url)
  end

  def scrape
    #main page
    page.forms[0].field_with(name: 'kirjaamo').option_with(value: 'YMPA').click
    meetings_page = page.forms[0].submit

    #results
    meetings_page.parser.css('table.list a')[0..-2].map do |link|
      meeting_page = Mechanize::Page::Link.new(link, agent, meetings_page).click
      name = meeting_page.parser.css('td.header').text.scan(/(?:\:).*/).first.gsub(':','')

      pdf_link = meeting_page.links.find { |l| l.text == 'Tiedoksi merkittävät asiat' }
      fetch_pdf(pdf_link, name)
    end
  end

  def fetch_pdf(link, name)
    return unless link
    pdf_file = link.click
    File.open("#{name}.pdf", 'w+b') do |file|
      file << pdf_file.body.strip
    end
    "#{name}.pdf"
  end
end

class YmpaResultPdf
  attr_reader :reader

  def initialize(file)
    @reader = PDF::Reader.new(file)
  end

  def scrape
    pages = reader.pages(&:text)
    pages = pages.join("\n")
    pages = pages.gsub(/\n{2}\d{1,2}.\d{1,2}.\d{4}\n{2}/, '')
    pages = pages.gsub(/Rakennustarkastaja.*päätökset\s/, '')
    unformatted_permits = pages.scan(/^(\s{0,1}\d+\s+.*?)(?=^\s{0,1}\d+|^Rakennustarkastajan päätösehdotus|\z)/m)
    unformatted_permits.map { |i| permit_builder(i) }
  end

  def permit_builder(item)
    index = 0
    items = item.first.split("\n")
    items = items.reject(&:empty?)
    permit_code, owner, pori_code = items[index].split(/\s{2,}/)
    index += 1

    row = items[index].strip
    until check_for_property_id(row)
      row = items[index].strip
      owner.concat(" & #{row}") unless row.empty?
      index += 1
      row = items[index].strip
    end

    property_id, place = items[index].split(/\s/).reject(&:empty?)
    index += 1

    index += 1 if items[index].empty?
    address = items[index].strip
    index += 1
    index += 1 if items[index].empty?
    postal_code, town = items[index].strip.split(' ')
    index += 1
    index += 1 if items[index].empty?
    reason = items[index].strip
    reason = reason.gsub(/\s{2,}\d+$/, '')
    index += 1
    info = items[index..-1].map do |i|
      i = i.strip.gsub(/^-/, '')
      i = i.gsub(/^\d/, '')
      i.gsub(/^\s.*?\d/, '')
    end.join

    combined_address = [address, postal_code, town].join(' ')

    Permit.new(owner, property_id, combined_address, reason, info)
  end

  def check_for_property_id(row)
    (row =~ /^\d{1,4}(-\d{1,4}){2,}/) == 0
  end
end
