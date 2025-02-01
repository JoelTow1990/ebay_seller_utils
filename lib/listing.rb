class Listing
  attr_reader :metadata, :image_urls

  def initialize(data)
    @metadata = {
      'Title' => data[:title],
      'Description' => data[:description],
      'CategoryName' => data[:category_name],
      'StartPrice' => data[:start_price],
      'MinimumBestOfferPrice' => data[:minimum_offer],
      'ConditionDisplayName' => data[:condition],
      'ConditionDescription' => data[:condition_description],
      'Quantity' => data[:quantity],
      'QuantitySold' => data[:quantity_sold]
    }.compact
    @image_urls = data[:image_urls]
  end

  def hash
    metadata.hash
  end

  def eql?(other)
    return false unless other.is_a?(self.class)
    metadata == other.metadata
  end
end