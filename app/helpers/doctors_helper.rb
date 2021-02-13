module DoctorsHelper
  def link_to_suspend_or_delete(doctor)
    if doctor.is_deleteable
      link_to t(:delete), doctor, :method => :delete, data: { confirm: t(:are_you_sure) }, 'data-icon' => '-'
    else
      link_to doctor.is_active ? t(:suspend) : t(:activate), doctor, :method => :delete,
                                                                     data: { confirm: t(:are_you_sure) }, 'data-icon' => (doctor.is_active ? '-' : '+').to_s
    end
  end
end
