class Chunk::Extractor
  SIZE = 1000
  OVERLAP = 150

  def initialize(document, path)
    @document = document
    @path = path
    @tracker = HeadingTracker.new(document.title)
    @rows = nil
  end

  def rows
    @rows ||= begin
      rows = []
      PDF::Reader.new(@path).pages.each_with_index do |page, index|
        @buffer = []
        page.text.to_s.split("\n").each { |line| process_line(line) }
        rows.concat(page_rows(@buffer.join("\n"), index + 1))
      end
      rows
    end
  end

  private

  def process_line(line)
    text = @tracker.scan(line)
    @buffer << text if text
  end

  def page_rows(text, page)
    text = text.strip
    return [] if text.empty?

    [].tap do |rows|
      start = 0
      loop do
        rows << { document_id: @document.id, content: text[start, SIZE], page:, section_path: }
        break if start + SIZE >= text.length
        start += SIZE - OVERLAP
      end
    end
  end

  def section_path
    @tracker.section_path
  end
end
