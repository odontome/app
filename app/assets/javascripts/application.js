
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

  // Wrap every rails date_select element in a column
  $('select[class*="date-select"]').wrap('<div class="col-4" />');
});

