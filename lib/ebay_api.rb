require 'net/http'
require 'nokogiri'
require 'uri'

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
        xml.StartTimeTo "2025-02-16T23:59:59.999Z"
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
