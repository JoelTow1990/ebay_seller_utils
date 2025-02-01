require 'date'

class DateRangeIterator
  def initialize(start_date:, end_date: Date.today, increment: 120)
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @increment = increment
  end

  def each
    current_start = @start_date
    current_end = end_date(current_start)

    while current_end < Date.today
      yield current_start, current_end
      current_start = current_end
      current_end = end_date(current_start)
    end
  end

  def end_date(start_date)
    [start_date + @increment, @end_date].min
  end

  def parse_date(date_string)
    return date_string if date_string.is_a?(Date)
    Date.strptime(date_string, "%d/%m/%Y")
  rescue ArgumentError
    raise ArgumentError, "Invalid date format. Use DD/MM/YYYY, got: #{date_string}"
  end
end