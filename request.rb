require 'dotenv'
require 'fileutils'
require 'mini_magick'
require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'uri'

Dotenv.load
FileUtils.cd(__dir__)

class EbayAPI
  HEADERS = {
    'X-EBAY-API-SITEID' => '15',
    'X-EBAY-API-COMPATIBILITY-LEVEL' => '967',
    'X-EBAY-API-CALL-NAME' => 'GetSellerList'
  }

  def initialize(api_uri, user_id, auth_token)
    @api_uri = api_uri
    @user_id = user_id
    @auth_token = auth_token
  end

  def body(page:)
    Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.GetSellerListRequest(xmlns: "urn:ebay:apis:eBLBaseComponents") do
        xml.RequesterCredentials do
          xml.eBayAuthToken @auth_token
        end
        xml.ErrorLanguage "en_US"
        xml.WarningLevel "High"
        xml.DetailLevel "ReturnAll"
        xml.StartTimeFrom "2024-12-01T00:00:00.000Z"
        xml.StartTimeTo "2025-01-16T23:59:59.999Z"
        xml.UserID @user_id
        xml.IncludeWatchCount "true"
        xml.WarningLevel "High"
        xml.Pagination do
          xml.EntriesPerPage "20"
          xml.PageNumber "#{page}"
        end
      end
    end.to_xml
  end

  def request(body)
    request = Net::HTTP::Post.new(@api_uri.path)
    HEADERS.each do |field, value|
      request[field] = value
    end
    request.body = body
    request
  end

  def response(request)
    http = Net::HTTP.new(@api_uri.host, @api_uri.port)
    http.use_ssl = true
    http.request(request)
  end

  def pages_to_scrape(response)
    doc = parse_response(response)
    doc.at_xpath('//ns:PaginationResult/ns:TotalNumberOfPages').text.to_i
  end

  def listings(response)
    doc = parse_response(response)
    doc.xpath('//ns:Item', 'ns')
  end

  private

  def parse_response(response)
    doc = Nokogiri::XML(response.body)
    doc.root.add_namespace_definition('ns', 'urn:ebay:apis:eBLBaseComponents')
    doc
  end
end

class Listing
  DESIRED_METADATA = [
    'Title',
    'Description',
    'PrimaryCategory/ns:CategoryName',
    'StartPrice',
    'ListingDetails/ns:MinimumBestOfferPrice',
    'ConditonDisplayName',
    'ConditionDescription',
  ]

  def initialize(node)
    @node = node
  end

  def metadata
    @metadata ||= DESIRED_METADATA.each_with_object({}) do |field, hash|
      data = text_data(field)
      next if data.nil?

      hash[field_name(field)] = data
    end
  end

  def image_urls
    @node.xpath('ns:PictureDetails/ns:PictureURL').map(&:text)
  end

  private

  def camelize(string)
    string.split('_').map(&:capitalize).join
  end

  def text_data(field)
    @node.xpath("ns:#{field}").text&.gsub(/<\/?[^>]*>/, '')&.strip
  end

  def field_name(field)
    split = field.split('/ns:')
    split.length > 1 ? split[1] : field
  end
end

def directory_name(listing)
  listing.metadata['CategoryName'].split(/[^\w]+/).first
end

def write_listing_metadata(listing)
  filename = 'metadata.txt'
  write_mode = File.exist?(filename) ? 'w' : 'wx'

  File.open('metadata.txt', write_mode) do |f|
    listing.metadata.each do |field, data|

      f.write("#{field}: #{data}\n")
    end
  end
end

def retrieve_and_save_image(url, save_name)
  URI.open(url) do |webp_image|
    image = MiniMagick::Image.read(webp_image.read)

    image.format "png"
    image.write "#{save_name}.png"
  end
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

api_uri = URI('https://api.ebay.com/ws/api.dll')
user_id = ENV["USER_ID"]
auth_token = ENV["AUTH_TOKEN"]

ebay_api = EbayAPI.new(
  api_uri,
  user_id,
  auth_token,
)

request = ebay_api.request(
  ebay_api.body(page: 1)
  )
response = ebay_api.response(request)

(1..ebay_api.pages_to_scrape(response)).each do |page|
  request = ebay_api.request(
    ebay_api.body(page: page)
    )
  response = ebay_api.response(request)

  puts "Scraping page #{page}"
  puts "Response: #{response}"
  ebay_api.listings(response).each_with_index do |listing, idx|
    listing = Listing.new(listing)
    puts "Processing listing #{idx} of page #{page}"
    directory = directory_name(listing)
    FileUtils.mkdir(directory) unless File.exist?(directory) && File.directory?(directory)
    FileUtils.cd(directory) do
      snake_name = listing.metadata['Title'].gsub(/[^\w ]/, '').gsub(/ +/, ' ').gsub(' ', '_').downcase
      FileUtils.mkdir(snake_name) unless File.exist?(snake_name) && File.directory?(snake_name)
      FileUtils.cd(snake_name) do
        write_listing_metadata(listing)

        listing.image_urls.each_with_index do |url, i|
          image_name = "#{snake_name}#{i}"

          retrieve_and_save_image(url, image_name)
        end
      end
    end
  end
end


