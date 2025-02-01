require 'nokogiri'

class EbayResponseParser
  def initialize(response)
    @doc = Nokogiri::XML(response.body)
    @doc.root.add_namespace_definition('ns', 'urn:ebay:apis:eBLBaseComponents')
  end

  def total_pages
    @doc.at_xpath('//ns:PaginationResult/ns:TotalNumberOfPages').text.to_i
  end

  def parse_listings
    @doc.xpath('//ns:Item', 'ns').map do |node|
      {
        title: extract_text(node, 'Title'),
        description: extract_text(node, 'Description'),
        category_name: extract_text(node, 'PrimaryCategory/ns:CategoryName'),
        start_price: extract_text(node, 'StartPrice'),
        minimum_offer: extract_text(node, 'ListingDetails/ns:MinimumBestOfferPrice'),
        condition: extract_text(node, 'ConditionDisplayName'),
        condition_description: extract_text(node, 'ConditionDescription'),
        quantity: extract_text(node, 'Quantity'),
        quantity_sold: extract_text(node, 'SellingStatus/ns:QuantitySold'),
        image_urls: node.xpath('ns:PictureDetails/ns:PictureURL').map(&:text)
      }
    end
  end

  private

  def extract_text(node, field)
    node.xpath("ns:#{field}").text&.gsub(/<\/?[^>]*>/, '')&.strip
  end
end