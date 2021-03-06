module ApplicationHelper
  def connection_image_path(connection, args = {})
    if connection.photo.file
      connection.photo.url(:thumbnail)
    else
      asset_url('user_placeholder.png', args)
    end
  end

  def connection_image_tag(connection, args = {})
    if connection.photo.file
      image_tag(connection.photo.url(:thumbnail), args)
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

  def checkin_moving_average(checkins, pstart: nil, pend: Time.now, frequency: nil, offset: 1.month, avg_width: 4)
    return nil unless frequency && pstart && pend && !checkins.empty? && pstart < pend

    periods = []
    period_count = 0
    while pend.in(-period_count * offset - avg_width * frequency) >= pstart
      periods << { start: [pend.in(-period_count * offset - avg_width * frequency), pend.in(-(period_count+1) * offset)].min,
                   end: pend.in(-period_count * offset) }
      period_count += 1
    end
    return nil if periods.empty?

    periods.each do |period|
      local_avg_width = (period[:end] - period[:start]) / frequency
      local_avg_width = avg_width if local_avg_width < 0.1

      period[:avg_n_checkin] = checkins.where('time > ? and time <= ?', period[:start], period[:end]).count /
                               avg_width.to_f
    end
    periods.reverse!

    data = {
      labels: periods.map { |period| period[:end].strftime('%b %y') },
      datasets: [
        {
          label: 'Check-in moving average',
          backgroundColor: "#FAFCFF",
          borderColor: "#62B1FA",
          data: periods.map { |period| period[:avg_n_checkin] }
        }
      ]
    }
    return data
  end

  def connection_checkin_moving_average(connection, pstart: nil, pend: Time.now, offset: 1.month, avg_width: 4)
    return nil unless connection.live?

    return checkin_moving_average(connection.checkins,
                                  pstart: pstart || [1.year.ago, connection.history_start].max,
                                  pend: pend,
                                  frequency: connection.frequency,
                                  offset: offset,
                                  avg_width: avg_width)
  end
end
