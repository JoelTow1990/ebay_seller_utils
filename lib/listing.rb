require 'nokogiri'

class Listing
  DESIRED_METADATA = [
    'Title',
    'Description',
    'PrimaryCategory/ns:CategoryName',
    'StartPrice',
    'ListingDetails/ns:MinimumBestOfferPrice',
    'ConditionDisplayName',
    'ConditionDescription',
    'Quantity',
    'SellingStatus/ns:QuantitySold',
  ]

  class Metadata
    def initialize(attributes = {})
      attributes.each do |key, value|
        instance_variable_set("@#{key}", value)
        self.class.send(:define_method, key) { instance_variable_get("@#{key}") }  
      end
    end

    def keys
      instance_variables.map { |attr| attr.to_s.delete("@").to_sym }
    end

    def [](key)
      send(key)
    end

    def each
      to_h.each do |k, v|
        yield(k, v)
      end
    end

    def to_h
      keys.each_with_object({}) do |attribute, hash|
        hash[attribute] = send(attribute)
      end
    end

    def ==(other)
      return false unless other.is_a?(Metadata)

      to_h == other.to_h
    end

    def self.from_txt(file)
      attributes = {}

      File.open(file, "r") do |f|
        f.each_line do |line|
          next if line.strip.empty?

          key, value = line.split(":", 2).map(&:strip)
          attributes[key.to_sym] = value if key && value
        end
      end

      new(attributes)
    end
  end

  def initialize(node)
    @node = node
  end

  def metadata
    @metadata ||= Metadata.new(
      DESIRED_METADATA.each_with_object({}) do |field, hash|
        data = text_data(field)
        next if data.nil?

        hash[field_name(field)] = data
      end
    )
  end

  def image_urls
    @node.xpath('ns:PictureDetails/ns:PictureURL').map(&:text)
  end

  def ==(other)
    return false unless other.is_a?(self.class)

    metadata == other.metadata
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
