require 'dotenv'
require 'fileutils'
require 'mini_magick'
require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'uri'

Dotenv.load
FileUtils.cd(__dir__)

DESIRED_METADATA = [
  'Title',
  'Description',
  'PrimaryCategory/ns:CategoryName',
  'StartPrice',
  'ListingDetails/ns:MinimumBestOfferPrice',
  'ConditonDisplayName',
  'ConditionDescription',
]

api_uri = URI('https://api.ebay.com/ws/api.dll')

def body(page: 1)
  <<~XML
    <?xml version="1.0" encoding="utf-8"?>
    <GetSellerListRequest xmlns="urn:ebay:apis:eBLBaseComponents">
      <RequesterCredentials>
        <eBayAuthToken>#{ENV["AUTH_TOKEN"]}</eBayAuthToken>
      </RequesterCredentials>
      <ErrorLanguage>en_US</ErrorLanguage>
      <WarningLevel>High</WarningLevel>
      <DetailLevel>ReturnAll</DetailLevel> 
      <StartTimeFrom>2024-12-01T00:00:00.000Z</StartTimeFrom> 
      <StartTimeTo>2025-01-16T23:59:59.999Z</StartTimeTo> 
      <UserID>#{ENV["USER_ID"]}</UserID>
      <IncludeWatchCount>true</IncludeWatchCount> 
      <WarningLevel>High</WarningLevel>
      <Pagination> 
        <EntriesPerPage>20</EntriesPerPage> 
        <PageNumber>#{page}</PageNumber>
      </Pagination> 
    </GetSellerListRequest>
  XML
end

def request(body, uri)
  request = Net::HTTP::Post.new(uri.path)
  request['X-EBAY-API-SITEID'] = '15'
  request['X-EBAY-API-COMPATIBILITY-LEVEL'] = '967'
  request['X-EBAY-API-CALL-NAME'] = 'GetSellerList'

  request.body = body
  request
end

def response(request, uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  http.request(request)
end

def parse_response(response)
  doc = Nokogiri::XML(response.body)
  doc.root.add_namespace_definition('ns', 'urn:ebay:apis:eBLBaseComponents')
  doc
end

def item_listings(response)
  # doc = Nokogiri::XML(response.body)
  # doc.root.add_namespace_definition('ns', 'urn:ebay:apis:eBLBaseComponents')
  parse_response(response).xpath('//ns:Item', 'ns')
end

def field_name(field)
  split = field.split('/ns:')
  split.length > 1 ? split[1] : field
end

def text_data(listing, field)
  listing.xpath("ns:#{field}").text&.gsub(/<\/?[^>]*>/, '')&.strip
end

def directory_name(listing)
  listing.xpath(
    "ns:PrimaryCategory/ns:CategoryName"
    ).text
     .split(/[^\w]+/)
     .first
end

def write_listing_metadata(listing)
  filename = 'metadata.txt'
  write_mode = File.exist?(filename) ? 'w' : 'wx'

  File.open('metadata.txt', write_mode) do |f|
    DESIRED_METADATA.each do |field|
      data = text_data(listing, field)
      next if data.nil?

      f.write("#{field_name(field)}: #{data}\n")
    end
  end
end

def image_urls(listing)
  listing.xpath('ns:PictureDetails/ns:PictureURL').map(&:text)
end

def retrieve_and_save_image(url, save_name)
  URI.open(url) do |webp_image|
    image = MiniMagick::Image.read(webp_image.read)

    image.format("png")
    image.write("#{save_name}.png")
  end
end

def pages_to_scrape(response)
  parse_response(response).xpath(
    '//ns:PaginationResult/ns:TotalNumberOfPages', 'ns' => 'urn:ebay:apis:eBLBaseComponents'
  ).text.to_i
end

# Note, pretty clearly there is a listing class emerging here
# The rest is maybe done by Thor class and handled by external libraries
# But you are building way too much logic around handling a listing
# Probably there is a request handling class
# And a persister class to manage logic of saving
#Should the persister know naming conventions used or is that for some driver program or the execute 
# method to know? I think I lean to the latter

# This is essentially going to be execute - need to wrap in iteration over responses
# TODO method for getting iterations
request = request(body, api_uri)
response = response(request, api_uri)

(1..pages_to_scrape(response)).each do |page|
  request = request(body(page: page), api_uri)
  response = response(request, api_uri)

  puts "Scraping page #{page}"
  item_listings(response).each_with_index do |listing, idx|
    puts "Processing listing #{idx} of page #{page}"
    directory = directory_name(listing)
    FileUtils.mkdir(directory) unless File.exist?(directory) && File.directory?(directory)
    FileUtils.cd(directory) do
      snake_name = listing.xpath("ns:Title").text.gsub(/[^\w ]/, '').gsub(/ +/, ' ').gsub(' ', '_').downcase
      FileUtils.mkdir(snake_name) unless File.exist?(snake_name) && File.directory?(snake_name)
      FileUtils.cd(snake_name) do
        write_listing_metadata(listing)

        image_urls(listing).each_with_index do |url, i|
          image_name = "#{snake_name}#{i}"

          retrieve_and_save_image(url, image_name)
        end
      end
    end
  end
end
#puts pages_to_scrape(response)