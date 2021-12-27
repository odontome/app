
//= require jquery3
//= require jquery_ujs
//= require fullcalendar.min
//= require jquery-ui-1.10.2.custom.min
//= require jquery.ui.touch
//= require jquery.autoSuggest
//= require jstz.min
//= require tabler.min
//= require tom-select.base.min

// This function prevents the session from ending
window.iCallServerId = setInterval(function (){ var remoteURL = '/'; $.get(remoteURL); }, 900000);

$(function(){
  var popoverTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="popover"]'))
  var popoverList = popoverTriggerList.map(function (popoverTriggerEl) {
    return new bootstrap.Popover(popoverTriggerEl)
  })
});