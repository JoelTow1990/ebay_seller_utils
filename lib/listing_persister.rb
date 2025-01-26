require 'fileutils'
require 'mini_magick'
require 'uri'

class ListingPersister
  def initialize(listing)
    @listing = listing
  end

  def persist
    category_dir = normalised_category
    FileUtils.mkdir(category_dir) unless File.directory?(category_dir)
    FileUtils.cd(category_dir) do
      persist_dir = normalised_title
      FileUtils.mkdir(persist_dir) unless File.directory?(persist_dir)
      
      FileUtils.cd(persist_dir) do
        persist_metadata
        persist_images
      end
    end
  end

  def persist_metadata
    filename = 'metadata.txt'
    write_mode = File.exist?(filename) ? 'w' : 'wx'

    File.open('metadata.txt', write_mode) do |f|
      @listing.metadata.each do |field, data|

        f.write("#{field}: #{data}\n")
      end
    end
  end

  def persist_images
    base_name = normalised_title
    @listing.image_urls.each_with_index do |url, idx|
      image_name = "#{base_name}#{idx}"
      retrieve_and_persist_image(url, image_name)
    end
  end

  def retrieve_and_persist_image(url, save_name)
    URI.open(url) do |webp_image|
      image = MiniMagick::Image.read(webp_image.read)

      image.format "png"
      image.write "#{save_name}.png"
    end
  end

  private

  def normalised_category
    @listing.metadata['CategoryName'].split(/[^\w]+/).first
  end

  def normalised_title
    @listing.metadata['Title'].gsub(/[^\w ]/, '').gsub(/ +/, ' ').gsub(' ', '_').downcase
  end
end
