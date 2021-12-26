
//= require jquery
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