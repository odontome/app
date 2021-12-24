
//= require jquery
//= require jquery_ujs
//= require fullcalendar.min
//= require jquery-ui-1.10.2.custom.min
//= require jquery.ui.touch
//= require jquery.autoSuggest
//= require jstz.min
//= require tabler.min

// This function prevents the session from ending
window.iCallServerId = setInterval(function (){ var remoteURL = '/'; $.get(remoteURL); }, 900000);

function selectText(element) {
  var doc = document
      , text = element
      , range, selection
  ;
  if (doc.body.createTextRange) {
      range = document.body.createTextRange();
      range.moveToElementText(text);
      range.select();
  } else if (window.getSelection) {
      selection = window.getSelection();
      range = document.createRange();
      range.selectNodeContents(text);
      selection.removeAllRanges();
      selection.addRange(range);
  }
}
