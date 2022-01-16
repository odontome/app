# frozen_string_literal: true

module DoctorsHelper
  def link_to_suspend_or_delete(doctor, options)
    if (doctor.is_deleteable || doctor.is_active) && options.dig(:class)&.exclude?("btn")
      options.dig(:class).concat(' text-red')
    end

    if doctor.is_deleteable
      link_to t(:delete), doctor, :method => :delete, **options, data: { confirm: t(:are_you_sure) }
    else
      link_to doctor.is_active ? t(:suspend) : t(:activate), doctor, **options, :method => :delete,
                                                                     data: { confirm: t(:are_you_sure) }
    end
  end

  def status_tag(doctor)
    if doctor.is_active
      label_tag t(:active), :green
    else
      label_tag t(:suspended), :red
    end
  end
end
