$(function() {
  $('.autocomplete').autocomplete({
    source: '/patients.json',
    delay: 500,
    classes: {
      "ui-autocomplete": "dropdown-menu"
    },
    search: function(event, ui) {
      $('.spinner-border').removeClass('d-none');
    },
    select: function(event, ui) {  
      $('#appointment_patient_id_').val(ui.item.id);
      $('.autocomplete').val(ui.item.fullname);

      // Don't replace the text field with the id
      event.preventDefault();
    },
    response: function(event, ui) {
      $('.spinner-border').addClass('d-none');
    },
    change: function( event, ui ) {
      $('#appointment_patient_id_').val(null);
    },
  }).autocomplete("instance")._renderItem = function(ul, item) {
    var item = $('<a href="" class="dropdown-item" data-theme="none">' + item.fullname + '</a>')
    return $("<li data-theme='none'>").append(item).appendTo(ul);
  };
});