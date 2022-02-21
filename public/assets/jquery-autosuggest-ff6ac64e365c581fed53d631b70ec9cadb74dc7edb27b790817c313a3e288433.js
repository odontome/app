$(function() {
  var didSelect = false;

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
      if (ui.item.id) {
        $('#appointment_patient_id').val(ui.item.id);
        $('.autocomplete').val(ui.item.fullname);
        // Update the patient's URL in the actions menu
        $('#patient-profile-link').attr('href', '/patients/' + ui.item.id);

        didSelect = true;
      }

      // Don't replace the text field with the id
      event.preventDefault();
    },
    response: function(event, ui) {
      if (ui.content.length === 0) {
        const noResult = { id: undefined, fullname: "No results found" };
        ui.content.push(noResult);
      }

      $('.spinner-border').addClass('d-none');
    },
    open: function(event, ui) {
      didSelect = false;
    },
    close: function(event, ui) {
      if (!didSelect) {
        $('#appointment_patient_id').val(null);
      }
    },
  })
  .autocomplete("instance")
  ._renderItem = function(ul, item) {
    var item = $('<a href="" class="dropdown-item" data-theme="none">' + item.fullname + '</a>')
    return $("<li data-theme='none'>").append(item).appendTo(ul);
  }
});
