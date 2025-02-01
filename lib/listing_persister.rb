require 'fileutils'
require 'mini_magick'
require 'uri'

class ListingPersister
  attr_writer :listing, :titles

  def initialize(listing)
    @listing = listing
    @record = Set.new
    @titles = Hash.new(0)
  end

  def persist
    category_dir = normalised_category
    puts "Category dir: #{category_dir}"
    FileUtils.mkdir(category_dir) unless File.directory?(category_dir)
    FileUtils.cd(category_dir) do
      persist_dir = normalised_title
      puts "Persist dir: #{persist_dir}"
      FileUtils.mkdir(persist_dir) unless File.directory?(persist_dir)
      
      FileUtils.cd(persist_dir) do
        puts "PWD: #{FileUtils.pwd}"
        puts "Current record: #{@record}"
        return unless valid_entry?

        persist_dir = unique_entry? ? persist_dir : persist_dir + random_char

        update_record!
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
        puts "Field: #{field}"
        puts "Data: #{data}"
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

  def valid_entry?
    return true unless @record.include?(@listing)
    
    false
  end

  def unique_entry?
    return true unless @titles.keys.include?(normalised_title)

    false
  end

  def update_record!
    @record.add(@listing)
    @titles[normalised_title] += 1
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
