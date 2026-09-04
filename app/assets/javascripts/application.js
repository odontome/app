//= require jquery3
//= require jquery_ujs
//= require libs/fullcalendar/index.global.min
//= require jquery-ui.min
//= require jstz.min
//= require js/tabler.min
//= require tom-select.base.min
//= require apexcharts.min
//= require masonry.min
//= require copy
//= require ai

// This function prevents the session from ending
window.iCallServerId = setInterval(function () {
  var remoteURL = "/";
  $.get(remoteURL);
}, 900000);

$(function () {
  // Tabler's automatic setup runs before body elements exist in our layouts.
  document.querySelectorAll('[data-bs-toggle="popover"]').forEach(function (element) {
    tabler.Popover.getOrCreateInstance(element);
  });
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(function (element) {
    tabler.Tooltip.getOrCreateInstance(element);
  });

  // Wrap every rails date_select element in a column
  $('select[class*="date-select"]').wrap('<div class="col-4" />');

  // Enforce client-side profile picture size limits across the app.
  function setupProfilePictureGuards(root) {
    var inputs = (root || document).querySelectorAll(
      "[data-profile-picture-input]"
    );

    inputs.forEach(function (input) {
      if (input.dataset.profilePictureBound === "true") return;
      input.dataset.profilePictureBound = "true";

      input.addEventListener("change", function (event) {
        var target = event.currentTarget;
        var files = target.files;
        var maxSize = parseInt(target.dataset.maxFileSize, 10);
        target.setCustomValidity("");

        if (!files || !files.length || !maxSize) return;

        var oversizedFile = Array.prototype.find.call(files, function (file) {
          return file.size > maxSize;
        });

        if (!oversizedFile) return;

        var message =
          target.dataset.maxFileSizeMessage || "Selected file is too large.";
        target.value = "";
        target.setCustomValidity(message);
        target.reportValidity();
        window.setTimeout(function () {
          target.setCustomValidity("");
        }, 4000);
      });
    });
  }

  setupProfilePictureGuards(document);
});
