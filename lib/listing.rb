require 'nokogiri'

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
