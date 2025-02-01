require 'net/http'
require 'nokogiri'
require 'uri'
require_relative 'ebay_response_parser'

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

  def build_request_body(page:, start_date:, end_date:)
    Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.GetSellerListRequest(xmlns: "urn:ebay:apis:eBLBaseComponents") do
        xml.RequesterCredentials do
          xml.eBayAuthToken @auth_token
        end
        xml.ErrorLanguage "en_US"
        xml.WarningLevel "High"
        xml.DetailLevel "ReturnAll"
        xml.StartTimeFrom format_date(start_date)
        xml.StartTimeTo format_date(end_date)
        xml.UserID @user_id
        xml.IncludeWatchCount "true"
        xml.WarningLevel "High"
        xml.Pagination do
          xml.EntriesPerPage "20"
          xml.PageNumber page
        end
      end
    end.to_xml
  end

  def create_http_request(body)
    request = Net::HTTP::Post.new(@api_uri.path)
    HEADERS.each { |field, value| request[field] = value }
    request.body = body
    request
  end

  def send_request(request)
    http = Net::HTTP.new(@api_uri.host, @api_uri.port)
    http.use_ssl = true
    http.request(request)
  end

  private

  def format_date(date)
    date.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
  end
end
