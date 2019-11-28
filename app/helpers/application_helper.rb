module ApplicationHelper
  def connection_image_path(connection, args = {})
    if connection.photo.file
      cl_image_path(connection.photo, args)
    else
      asset_url('user_placeholder.png', args)
    end
  end

  def connection_image_tag(connection, args = {})
    if connection.photo.file
      cl_image_tag(connection.photo, args)
    else
      image_tag('user_placeholder.png', args)
    end
  end

  def full_name(person)
    "#{person.first_name} #{person.last_name}"
  end

  def datetime_display(dte, missing = "Never")
    dte ? dte.strftime("%a %d %b %Y %k:%M") : missing
  end

  def date_display(dte, missing = "Never")
    dte ? dte.strftime("%a %d %b %Y") : missing
  end

  def checkin_date_display(checkin, missing = "Never")
    checkin ? date_display(checkin.time, missing) : missing
  end

  def last_checkin_date_display(connection, missing = "Never")
    checkin_date_display(connection.last_completed_past_checkin, missing)
  end

  def checkin_deadline_display(connection, missing = "Never", past = "ASAP", prefix = "by ")
    dte = connection.checkin_deadline
    if dte
      dte > Time.now ? "#{prefix}#{date_display(dte)}" : past
    else
      missing
    end
  end

  def birthday_display(dte, missing = "Unknown")
    dte ? dte.strftime("%d %b") : missing
  end

  def frequency_display(duration, missing = "Never")
    duration ? "Every #{duration.inspect.gsub(/^1 /, '')}" : missing
  end

  def pluralize_with_no(word, count)
    count.zero? ? "no #{word}" : "#{count} #{word.pluralize(count)}"
  end

  def duration_units
    [:days, :weeks, :months, :years]
  end

  def duration_value(duration)
    duration&.is_a?(ActiveSupport::Duration) ? duration.parts.first[1] : 0
  end

  def duration_unit_index(duration)
    duration&.is_a?(ActiveSupport::Duration) ? duration.parts.first[0] : :months
  end

  def connection_status(connection)
    status = []
    if connection.live?
      if connection.frequency?
        status << ['Frequency:', frequency_display(connection.frequency)]
        last_checkin = connection.last_checkin
        if last_checkin && last_checkin.time > Time.now
          status << ['Next:', date_display(last_checkin.time)]
        else
          if last_checkin
            # status << ['Last:', date_display(last_checkin.time)]
          end
          status << ['Next due by:', date_display(connection.checkin_deadline)]
        end
      end
    else
      status << ['Pending', '']
      # status << ['Imported on:', date_display(connection.created_at)]
    end
    return status
  end

  # def dashboard_message(args = {})
  #   return "Nothing requires your immediate attention. Good job!" if args.empty? || args.sum{ |_, n| n }.zero?

  #   actions = []
  #   if args[:n_feedbacks] && args[:n_feedbacks].positive?
  #     actions << ("have " + pluralize_with_no("past check-in", args[:n_feedbacks]) + " to give feedback on")
  #   end
  #   if args[:n_connections_checkin] && args[:n_connections_checkin].positive?
  #     actions << ("should get back in touch with " + pluralize_with_no("connection", args[:n_connections_checkin]))
  #   end
  #   if args[:n_upcomings] && args[:n_upcomings].positive?
  #     actions << ("have " + pluralize_with_no("upcoming check-in", args[:n_upcomings]) + " next week")
  #   end
  #   "You " + actions.to_sentence + "."
  # end

  def checkin_moving_average(checkins, pstart: nil, pend: Time.now, frequency: nil, offset: 1.month, avg_window: 4)
    return nil unless frequency && pstart && pend && !checkins.empty? && pstart < pend

    periods = []
    period_count = 0
    while (pend.in(-period_count*offset -avg_window*frequency) >= pstart) do
      periods << {start: pend.in(-period_count*offset -avg_window*frequency), end: pend.in(-period_count*offset) }
      period_count += 1
    end
    return nil if periods.empty?

    periods.each do |period|
      period[:avg_n_checkin] = checkins.where('time > ? and time <= ?', period[:start], period[:end]).count / avg_window.to_f
    end
    periods.reverse!

    data = {
      labels: periods.map { |period| period[:end].strftime('%b %y') },
      datasets: [
        {
          label: 'Check-in moving average',
          backgroundColor: "rgba(220,220,220,0.2)",
          borderColor: "rgba(220,220,220,1)",
          data: periods.map { |period| period[:avg_n_checkin]}
        }
      ]
    }
    return data
  end
end
