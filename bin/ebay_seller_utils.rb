#!/usr/bin/env ruby

require 'date'
require 'dotenv'
require 'fileutils'
require 'thor'

require_relative '../lib/date_range_iterator'
require_relative '../lib/ebay_api'
require_relative '../lib/ebay_response_parser'
require_relative '../lib/listing'
require_relative '../lib/listing_persister'

class EbaySellerUtils < Thor

  def initialize(*args)
    super(*args)
    setup_environment
    @ebay_api = EbayAPI.new(
      URI('https://api.ebay.com/ws/api.dll'),
      ENV["USER_ID"],
      ENV["AUTH_TOKEN"]
    )

    @logger = Logger.new('errors.txt')
    @persister = ListingPersister.new({})
  end

  desc 'fetch_all', 'fetches all listings in specified date range'
  default_task :fetch_all
  option :dry_run, default: true, type: :boolean
  option :start_date, default: "01/01/2022", type: :string
  option :end_date, default: Date.today.strftime("%d/%m/%Y"), type: :string
  def fetch_all
    puts "[EXECUTING] Task in progress with dry_run=#{options[:dry_run]}..."
    start_date = options[:start_date]
    end_date = options[:end_date]
    puts "Fetching all listings in range #{start_date} : #{end_date}"

    iterator = DateRangeIterator.new(
      start_date: start_date,
      end_date: end_date,
    )

    iterator.each do |start_date, end_date|
      puts "Current date range: #{start_date.to_s} - #{end_date.to_s}"

      page_range(start_date, end_date).each do |page|
        response = current_response(page, start_date, end_date)
        puts "Extracting data from page #{page}"
        next if response.nil?

        process_listings(response) unless options[:dry_run]
      end
    end
    output_duplicates
    
    puts "[SUCCESS] Task fetch_all completed successfully!"
  end

  desc 'fetch_page', 'fetch data from specified page'
  option :dry_run, default: true, type: :boolean
  option :page, default: 1, type: :numeric
  option :start_date, default: "01/01/2022", type: :string
  option :end_date, default: Date.today.strftime("%d/%m/%Y"), type: :string

  def fetch_page
    puts "[EXECUTING] Task in progress with dry_run=#{options[:dry_run]}..."
    start_date = options[:start_date]
    end_date = options[:end_date]
    puts "Fetching listings from page #{options[:page]} in range #{start_date} : #{end_date}"

    response = current_response(options[:page], start_date, end_date)
    puts "Extracting data from page #{options[:page]}"

    process_listings(response) unless options[:dry_run]

    puts "[SUCCESS] Task fetch_page completed successfully!"
  end

  private

  def setup_environment
    Dotenv.load
    FileUtils.cd(Dir.home)
    FileUtils.mkdir("EbayListings") unless File.directory?("EbayListings")
    FileUtils.cd("EbayListings")
  end

  def current_response(page, start_date, end_date)
    body = @ebay_api.build_request_body(
      page: page,
      start_date: start_date,
      end_date: end_date
    )
    request = @ebay_api.create_http_request(body)
    @ebay_api.send_request(request)
  rescue StandardError => e
    @logger.log_response_error(page, e)
    nil
  end

  def page_range(start_date, end_date)
    response = current_response(1, start_date, end_date)
    parser = EbayResponseParser.new(response)
    total_pages = parser.total_pages
    1..total_pages
  end

  def process_listings(response)
    parser = EbayResponseParser.new(response)
    parser.parse_listings.each do |listing|
      process_single_listing(listing)
    end
  end

  def process_single_listing(listing)
    listing = Listing.new(listing)
    @persister.listing = listing
    @persister.persist unless options[:dry_run]

  rescue StandardError => e
    @logger.log_listing_error(listing)
  end

  def output_duplicates
    @persister.titles.select { |_, v| v > 1 }.each do |title, count|
      puts "Title: #{title} Count: #{count}"
    end
  end

  class Logger
    def initialize(log_file)
      @log_file = log_file
      FileUtils.touch(@log_file) unless File.exist?(@log_file)
    end

    def log_response_error(page, error)
      puts "Error with request on page #{page}: #{error}"
    end

    def log_listing_error(listing)
      File.open(@log_file, 'a') do |f|
        f.puts "Failed to process listing: #{listing.title}"
      end
    end
  end
end

EbaySellerUtils.start(ARGV)
