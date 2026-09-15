class HeadingTracker
  HEADING = /\A(\d+(?:\.\d+)*)?\s*[A-Z][A-Za-z ,\-]{2,60}\z/

  def initialize(title)
    @title = title
    @stack = []
  end

  # Classifies one text line: heading lines update the section stack and
  # return nil; every other line returns its stripped text ("" for blanks).
  def scan(line)
    stripped = line.strip
    if heading?(stripped)
      push(stripped)
      nil
    else
      stripped
    end
  end

  def section_path
    ([ @title ] + @stack).join(" / ")
  end

  private

  def heading?(line)
    !line.empty? && !line.end_with?(".") && line.split.length <= 8 && line =~ HEADING
  end

  def push(line)
    number = line[/\A\d+(?:\.\d+)*/]
    if number
      depth = number.split(".").length
      @stack = @stack.first(depth - 1)
      @stack << line
    else
      @stack = [ line ]
    end
  end
end
