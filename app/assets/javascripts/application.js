
//= require jquery3
//= require jquery_ujs
//= require fullcalendar.min
//= require jquery-ui.min
//= require jquery.ui.touch
//= require jstz.min
//= require tabler.min
//= require tom-select.base.min
//= require apexcharts.min
//= require masonry.min

// This function prevents the session from ending
window.iCallServerId = setInterval(function (){ var remoteURL = '/'; $.get(remoteURL); }, 900000);

$(function(){
  const popoverTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="popover"]'))
  popoverTriggerList.map(function (popoverTriggerEl) {
    return new bootstrap.Popover(popoverTriggerEl)
  });

  const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
  tooltipTriggerList.map(function (tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl)
  });

  // Auto-dismiss flash messages after 5 seconds
  $('[data-auto-dismiss="true"]').each(function() {
    var alert = $(this);
    setTimeout(function() {
      if (alert.hasClass('show')) {
        alert.alert('close');
      }
    }, 5000);
  });

  // Enhanced form validation
  $('form input, form textarea, form select').on('blur', function() {
    var field = $(this);
    var fieldName = field.attr('name');
    var fieldValue = field.val();
    var isRequired = field.hasClass('required') || field.closest('.mb-3').find('label').hasClass('required');
    
    // Clear previous validation states
    field.removeClass('is-valid is-invalid');
    field.siblings('.invalid-feedback, .valid-feedback').remove();
    
    // Basic validation
    if (isRequired && (!fieldValue || fieldValue.trim() === '')) {
      field.addClass('is-invalid');
      field.after('<div class="invalid-feedback">' + window.I18n.required_field + '</div>');
    } else if (field.attr('type') === 'email' && fieldValue) {
      var emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(fieldValue)) {
        field.addClass('is-invalid');
        field.after('<div class="invalid-feedback">' + window.I18n.invalid_email + '</div>');
      } else {
        field.addClass('is-valid');
      }
    } else if (fieldValue && fieldValue.trim() !== '') {
      field.addClass('is-valid');
    }
  });

  // Clear validation on focus
  $('form input, form textarea, form select').on('focus', function() {
    $(this).removeClass('is-valid is-invalid');
    $(this).siblings('.invalid-feedback, .valid-feedback').remove();
  });

  // Wrap every rails date_select element in a column
  $('select[class*="date-select"]').wrap('<div class="col-4" />');
});

