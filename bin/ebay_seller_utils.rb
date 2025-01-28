#!/usr/bin/env ruby

require 'date'
require 'dotenv'
require 'fileutils'
require 'thor'

require_relative '../lib/ebay_api'
require_relative '../lib/listing'
require_relative '../lib/listing_persister'

class EbaySellerUtils < Thor
  desc 'execute', <<~DESC
  From project root run `ruby bin/ebay_seller_utils.rb --dry_run={true|false}`
  Will query the ebay api to get all seller listings in hardcoded time period.
  Metadata from listings, and all associated images, are saved locally.
  The structure is:
    $HOME/EbayListings/Category/ListingTitle/*
      - metadata.txt in the relevant directory will store the text metadata
      - The images will be saved in a snake_case format derived from the listing titles.
  DESC
  default_task :execute
  option :dry_run, default: true, type: :boolean
  option :start_page, default: 1, type: :numeric
  option :start_date, default: "01/01/2022", type: :string
  option :end_date, default: "01/01/2022", type: :string
  option :single_iteration, default: false, type: :boolean

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

      start_date, end_date = initialize_dates(options[:start_date], options[:end_date])
      persister = ListingPersister.new({}) # A hack, you can't call any methods on this

      FileUtils.touch("Errors.txt") unless File.exist?("Errors.txt")

      while end_date < (Date.today + 2)
        request = ebay_api.request(
          ebay_api.body(
            page: 1,
            start_date: start_date,
            end_date: end_date,
            )
          )
        response = ebay_api.response(request)

        total_pages = ebay_api.pages_to_scrape(response)
        puts "Date range: #{start_date.to_s} - #{end_date.to_s}"
        puts "Total pages for this range: #{total_pages - (options[:start_page] - 1)}"

        (options[:start_page]..total_pages).each do |page|
          begin
            request = ebay_api.request(
              ebay_api.body(
                page: page,
                start_date: start_date,
                end_date: end_date,
                )
              )
            response = ebay_api.response(request)

            puts "Extracting data from page #{page}"

            begin
              ebay_api.listings(response).each_with_index do |listing, idx|
                listing = Listing.new(listing)
                persister.listing = listing

                puts "Processing listing #{idx} of page #{page}"
                persister.persist unless options[:dry_run]
              end
            rescue StandardError => e
              File.open("Errors.txt", 'a') do |f|
                f.puts("#{listing.title}")
              end
            end

          rescue StandardError => e
            puts "Error with request on page #{page}: #{e}"
            next
          end
        end

        start_date = end_date
        end_date = (end_date + 120)

        break if options[:single_iteration]
      end
    end

    puts "[SUCCESS] Task completed successfully!"
  end

  private

  def initialize_dates(start_date, end_date)
    if start_date == end_date
      starting = parse_date(start_date)
      ending = starting + 120
      [starting, ending]
    else
      [parse_date(start_date), parse_date(end_date)]
    end
  end

  def parse_date(date_string)
    Date.strptime(date_string, "%d/%m/%Y")
  end
end

EbaySellerUtils.start(ARGV)
