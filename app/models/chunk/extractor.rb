class Chunk::Extractor
  HEADING = /\A(\d+(?:\.\d+)*)?\s*[A-Z][A-Za-z ,\-]{2,60}\z/
  SIZE = 1000
  OVERLAP = 150

  def initialize(document, path)
    @document = document
    @path = path
    @stack = []
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
    stripped = line.strip
    if heading?(stripped)
      push_heading(stripped)
    elsif stripped.empty?
      @buffer << ""
    else
      @buffer << stripped
    end
  end

  def heading?(line)
    !line.empty? && !line.end_with?(".") && line.split.length <= 8 && line =~ HEADING
  end

  def push_heading(line)
    number = line[/\A\d+(?:\.\d+)*/]
    if number
      depth = number.split(".").length
      @stack = @stack.first(depth - 1)
      @stack << line
    else
      @stack = [ line ]
    end
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
    ([ @document.title ] + @stack).join(" / ")
  end
end
