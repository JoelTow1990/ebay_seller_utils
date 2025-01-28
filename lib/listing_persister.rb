require 'fileutils'
require 'mini_magick'
require 'uri'

class ListingPersister
  attr_writer :listing

  def initialize(listing)
    @listing = listing
    @record = {}
  end

  def persist
    category_dir = normalised_category
    FileUtils.mkdir(category_dir) unless File.directory?(category_dir)
    FileUtils.cd(category_dir) do
      persist_dir = normalised_title
      FileUtils.mkdir(persist_dir) unless File.directory?(persist_dir)
      
      FileUtils.cd(persist_dir) do
        return unless valid_entry?(persist_dir)

        persist_dir = entry_exists?(persist_dir) ? persist_dir + random_char : persist_dir

        update_record(persist_dir)
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
        puts "Writing #{field}: #{data}"
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

  def valid_entry?(persist_dir)
    return true unless entry_exists?(persist_dir)

    unique_entry?(persist_dir)
  end

  def entry_exists?(persist_dir)
     @record.keys.include?(persist_dir)
  end

  def unique_entry?(persist_dir)
    other_path = File.expand_path(@record[persist_dir])
    other = Listing::Metadata.from_txt(other_path)

    return true unless @listing.metadata == other

    false
  end

  def update_record(persist_dir)
    @record[persist_dir] = "#{persist_dir}/metadata.txt"
  end

  private

  def normalised_category
    @listing.metadata['CategoryName'].split(/[^\w]+/).first
  end

  def normalised_title
    @listing.metadata['Title'].gsub(/[^\w ]/, '').gsub(/ +/, ' ').gsub(' ', '_').downcase
  end

  def random_char
    ('a'..'z').to_a.sample
  end
end
