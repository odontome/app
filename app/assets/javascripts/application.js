
//= require jquery
//= require jquery_ujs
//= require bootstrap
//= require fullcalendar.min
//= require jquery-ui-1.10.2.custom.min
//= require jquery.ui.touch
//= require jquery.autoSuggest
//= require jquery.minicolors
//= require retina-1.1.0
//= require jstz.min
//= require theme

// This function prevents the session from ending
window.iCallServerId = setInterval(function (){ var remoteURL = '/'; $.get(remoteURL); }, 900000);
