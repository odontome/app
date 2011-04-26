module DoctorsHelper
  def link_to_suspend_or_delete(doctor)
    if doctor.is_deleteable
			link_to _('Delete'), doctor, :method => :delete, :confirm => _("Are you sure?"), :class => "g-button red"
		else
			link_to (doctor.is_active) ? _('Suspend') : _('Activate'), doctor, :method => :delete, :confirm => _("Are you sure?"), :class => "g-button #{(doctor.is_active) ? 'red' : 'green'}"
		end
  end
end
