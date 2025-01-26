require 'dotenv'
require 'fileutils'

require_relative '../lib/ebay_api'
require_relative '../lib/listing'
require_relative '../lib/listing_persister'

class EbaySellerUtils
  def execute
    Dotenv.load

    FileUtils.cd(Dir.home)
    FileUtils.mkdir("EbayListings") unless File.directory?("EbayListings")
    
    FileUtils.cd("EbayListings") do

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
          persister = ListingPersister.new(listing)
          puts "Processing listing #{idx} of page #{page}"
          persister.persist
        end
      end
    end
  end
end

if __FILE__ == $0
  EbaySellerUtils.new.execute
end



