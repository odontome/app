module DoctorsHelper
  def link_to_suspend_or_delete(doctor)
    if doctor.is_deleteable
			link_to _('Delete'), doctor, :method => :delete, :confirm => _("Are you sure?"), "data-icon" => "-"
		else
			link_to (doctor.is_active) ? _('Suspend') : _('Activate'), doctor, :method => :delete, :confirm => _("Are you sure?"), "data-icon" => "#{(doctor.is_active) ? '-' : '+'}"
		end
  end
end
