module DoctorsHelper
  def link_to_suspend_or_delete(doctor)
    if doctor.is_deleteable
			link_to t(:delete), doctor, :method => :delete, :confirm => t(:are_you_sure), "data-icon" => "-"
		else
			link_to (doctor.is_active) ? t(:suspend) : t(:activate), doctor, :method => :delete, :confirm => t(:are_you_sure), "data-icon" => "#{(doctor.is_active) ? '-' : '+'}"
		end
  end
end
