  
//= require jquery
//= require jquery_ujs
//= require_self
//= require bootstrap
//= require fullcalendar.min
//= require jquery-ui-1.10.2.custom.min
//= require jquery.autoSuggest
//= require theme

// This function prevents the session from ending
window.iCallServerId = setInterval(function (){ var remoteURL = '/'; $.get(remoteURL); }, 900000);