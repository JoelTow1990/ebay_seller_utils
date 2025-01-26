#!/usr/bin/env ruby

require 'dotenv'
require 'fileutils'
require 'thor'

require_relative '../lib/ebay_api'
require_relative '../lib/listing'
require_relative '../lib/listing_persister'

class EbaySellerUtils < Thor
  desc 'execute', <<~DESC
  From project root run `ruby ebay_seller_utils.rb --dry_run={true|false}`
  Will query the ebay api to get all seller listings in hardcoded time period.
  Metadata from listings, and all associated images, are saved locally.
  The structure is:
    $HOME/EbayListings/Category/ListingTitle/*
      - metadata.txt in the relevant directory will store the text metadata
      - The images will be saved in a snake_case format derived from the listing titles.
  DESC
  default_task :execute
  option :dry_run, default: true, type: :boolean

  def execute
    puts "[EXECUTING] Task in progress with dry_run=#{options[:dry_run]}..."

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

        puts "Extracting data from page #{page}"
        ebay_api.listings(response).each_with_index do |listing, idx|
          listing = Listing.new(listing)
          persister = ListingPersister.new(listing)
          puts "Processing listing #{idx} of page #{page}"
          persister.persist unless options[:dry_run]
        end
      end
    end

    puts "[SUCCESS] Task completed successfully!"
  end
end

EbaySellerUtils.start(ARGV)
