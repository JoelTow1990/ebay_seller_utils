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

    @ebay_api = EbayAPI.new(
      URI('https://api.ebay.com/ws/api.dll'),
      ENV["USER_ID"],
      ENV["AUTH_TOKEN"],
    )
    setup_environment
    start_date, end_date = initialize_dates(options[:start_date], options[:end_date])
    @persister = ListingPersister.new({}) # A hack, you can't call any methods on this

    while end_date < (Date.today + 2)
      puts "Date range: #{start_date.to_s} - #{end_date.to_s}"

      page_range(start_date, end_date).each do |page|
        response = current_response(page, start_date, end_date)
        puts "Extracting data from page #{page}"
        next if response.nil?

        process_listings(response)    
      end

      start_date = end_date
      end_date = (end_date + 120)

      break if options[:single_iteration]
    end

    puts "[SUCCESS] Task completed successfully!"
  end

  private

  def setup_environment
    FileUtils.cd(Dir.home)
    FileUtils.mkdir("EbayListings") unless File.directory?("EbayListings")
    FileUtils.cd("EbayListings")
    FileUtils.touch("errors.txt") unless File.exist?("Errors.txt")
  end

  def build_ebay_request(page, start_date, end_date)
    @ebay_api.request(
      @ebay_api.body(
        page: page,
        start_date: start_date,
        end_date: end_date
      )
    )
  end

  def current_response(page, start_date, end_date)
    request = build_ebay_request(page, start_date, end_date)
    return @ebay_api.response(request)

  rescue StandardError => e
    puts "Error with request on page #{page}: #{e}"
    return nil
  end

  def page_range(start_date, end_date)
    response = current_response(1, start_date, end_date)

    # TODO: Why is the client parsing responses for you?
    # And deciding how many pages to scrape?
    # I think there is a confusion of responsibilities here
    total_pages = @ebay_api.pages_to_scrape(response)
    

    options[:start_page]..total_pages
  end

  def process_listings(response)
    @ebay_api.listings(response).each_with_index do |listing, idx|
      listing = Listing.new(listing)
      @persister.listing = listing

      @persister.persist unless options[:dry_run]

    rescue StandardError => e
      File.open("Errors.txt", 'a') do |f|
        f.puts("#{listing.title}")
      end
    end
  end

  def initialize_dates(start_date, end_date)
    if start_date >= end_date
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
