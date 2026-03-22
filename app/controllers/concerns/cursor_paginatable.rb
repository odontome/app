# frozen_string_literal: true

module CursorPaginatable
  extend ActiveSupport::Concern

  private

  def encode_cursor(record, sort_column:, sort_direction:)
    payload = {
      id: record.id,
      sort_column: sort_column,
      sort_direction: sort_direction
    }

    if sort_column == self.class::SORT_LAST_VISIT
      payload[:last_visit_at] = record.last_visit_at&.iso8601
    else
      payload[:firstname] = record.firstname.to_s
      payload[:lastname] = record.lastname.to_s
    end

    Base64.urlsafe_encode64(payload.to_json)
  end

  def decode_cursor(token)
    JSON.parse(Base64.urlsafe_decode64(token)).symbolize_keys
  rescue JSON::ParserError, ArgumentError
    nil
  end

  def apply_cursor_scope(scope, decoded, sort_column:, sort_direction:)
    if sort_column == self.class::SORT_LAST_VISIT
      return apply_last_visit_cursor_scope(scope, decoded, sort_direction: sort_direction)
    end

    apply_name_cursor_scope(scope, decoded, sort_direction: sort_direction)
  end

  def apply_name_cursor_scope(scope, decoded, sort_direction:)
    comparator = sort_direction == self.class::SORT_DESC ? '<' : '>'

    scope.where(
      "firstname #{comparator} :firstname OR (firstname = :firstname AND (lastname #{comparator} :lastname OR (lastname = :lastname AND patients.id #{comparator} :id)))",
      firstname: decoded[:firstname].to_s,
      lastname: decoded[:lastname].to_s,
      id: decoded[:id].to_i
    )
  end

  def apply_last_visit_cursor_scope(scope, decoded, sort_direction:)
    cursor_last_visit = parse_cursor_time(decoded[:last_visit_at])
    cursor_id = decoded[:id].to_i

    if cursor_last_visit.nil?
      return scope.where('last_visits.last_visit_at IS NULL AND patients.id > :id', id: cursor_id)
    end

    comparator = sort_direction == self.class::SORT_ASC ? '>' : '<'

    scope.where(
      "(last_visits.last_visit_at IS NOT NULL AND (last_visits.last_visit_at #{comparator} :last_visit OR (last_visits.last_visit_at = :last_visit AND patients.id > :id))) OR last_visits.last_visit_at IS NULL",
      last_visit: cursor_last_visit,
      id: cursor_id
    )
  end

  def parse_cursor_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def apply_listing_sort(scope, sort_column:, sort_direction:)
    if sort_column == self.class::SORT_LAST_VISIT
      last_visit_direction = sort_direction == self.class::SORT_ASC ? 'ASC' : 'DESC'

      return scope.reorder(
        Arel.sql("CASE WHEN last_visits.last_visit_at IS NULL THEN 1 ELSE 0 END ASC, last_visits.last_visit_at #{last_visit_direction}, patients.id ASC")
      )
    end

    # name_direction is guaranteed to be 'ASC' or 'DESC' by normalize_sort_direction
    name_direction = sort_direction == self.class::SORT_DESC ? 'DESC' : 'ASC'
    scope.reorder(Arel.sql("firstname #{name_direction}, lastname #{name_direction}, patients.id #{name_direction}"))
  end
end
