class Image::Extractor
  MIN_PIXELS = 128 * 128
  CAPTION = /\A(Fig(ure)?|Image|Diagram|Chart|Table|Plate|Illustration)\b[\s.:]?\s*\d*/i
  PASSTHROUGH_CONTENT_TYPES = {
    "DCTDecode" => "image/jpeg",
    "DCT" => "image/jpeg",
    "JPXDecode" => "image/jp2"
  }.freeze

  def initialize(document, path)
    @document = document
    @path = path
    @tracker = HeadingTracker.new(document.title)
  end

  def rows
    @rows ||= extracted.map { |row| row.except(:bytes) }
  end

  # digest => { content_type:, bytes: } for every image carrying bytes —
  # Document.ingest! uploads exactly one blob per entry.
  def files
    @files ||= extracted.each_with_object({}) do |row, files|
      files[row[:digest]] = { content_type: row[:content_type], bytes: row[:bytes] } if row[:bytes]
    end
  end

  private

  def extracted
    @extracted ||= begin
      rows = []
      PDF::Reader.new(@path).pages.each_with_index do |page, index|
        rows.concat(page_rows(page, index + 1))
      end
      rows
    end
  end

  def page_rows(page, number)
    captions = scan_captions(page)
    section = @tracker.section_path
    image_streams(page).reject { |_name, stream| decorative?(stream) }
                        .each_with_index
                        .map { |(name, stream), position| build_row(name, stream, number, section, captions[position]) }
  end

  def scan_captions(page)
    page.text.to_s.split("\n").filter_map do |line|
      stripped = line.strip
      @tracker.scan(line)
      stripped if caption?(stripped)
    end
  end

  def caption?(line)
    !line.empty? && line.length <= 300 && line.match?(CAPTION)
  end

  def image_streams(page)
    page.xobjects.select { |_name, stream| stream.hash[:Subtype] == :Image }
  end

  def decorative?(stream)
    hash = stream.hash
    hash[:Width].to_i * hash[:Height].to_i < MIN_PIXELS
  end

  def build_row(name, stream, page, section, caption)
    hash = stream.hash
    width = hash[:Width].to_i
    height = hash[:Height].to_i
    filter = Array(hash[:Filter]).join(" ")
    content_type = PASSTHROUGH_CONTENT_TYPES[filter]
    bytes = content_type && stream.unfiltered_data
    {
      document_id: @document.id,
      page: page,
      section_path: section,
      caption: caption,
      name: name.to_s,
      content_type: content_type,
      width: width,
      height: height,
      color_space: color_space(hash[:ColorSpace]),
      filter: filter,
      digest: digest(bytes, name, width, height),
      bytes: bytes
    }
  end

  def color_space(value)
    case value
    when Symbol, String then value.to_s
    when Array then value.first.to_s
    end
  end

  def digest(bytes, name, width, height)
    bytes ? Digest::SHA256.hexdigest(bytes) : "#{name}:#{width}x#{height}"
  end
end
