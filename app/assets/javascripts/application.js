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
//= require copy

// This function prevents the session from ending
window.iCallServerId = setInterval(function () {
  var remoteURL = "/";
  $.get(remoteURL);
}, 900000);

// Theme switcher - FOUC prevention (runs immediately when DOM is ready)
document.addEventListener("DOMContentLoaded", function () {
  // Apply theme immediately to prevent FOUC
  const theme = localStorage.getItem("theme") || "light";
  const body = document.getElementById("app-body") || document.body;
  if (theme === "dark") {
    body.classList.remove("theme-light");
    body.classList.add("theme-dark");
  }
});

$(function () {
  const popoverTriggerList = [].slice.call(
    document.querySelectorAll('[data-bs-toggle="popover"]')
  );
  popoverTriggerList.map(function (popoverTriggerEl) {
    return new bootstrap.Popover(popoverTriggerEl);
  });

  const tooltipTriggerList = [].slice.call(
    document.querySelectorAll('[data-bs-toggle="tooltip"]')
  );
  tooltipTriggerList.map(function (tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl);
  });

  // Wrap every rails date_select element in a column
  $('select[class*="date-select"]').wrap('<div class="col-4" />');

  // Theme Switcher functionality
  const themeToggle = document.getElementById("theme-toggle");
  const lightIcon = document.querySelector(".light-icon");
  const darkIcon = document.querySelector(".dark-icon");
  const body = document.body;

  // Get current theme from localStorage or default to light
  const currentTheme = localStorage.getItem("theme") || "light";

  // Apply the current theme
  applyTheme(currentTheme);

  // Theme toggle click handler
  if (themeToggle) {
    themeToggle.addEventListener("click", function (e) {
      e.preventDefault();
      const newTheme = body.classList.contains("theme-dark") ? "light" : "dark";
      applyTheme(newTheme);
      localStorage.setItem("theme", newTheme);
    });
  }

  function applyTheme(theme) {
    if (theme === "dark") {
      body.classList.remove("theme-light");
      body.classList.add("theme-dark");
      if (lightIcon) lightIcon.style.display = "inline";
      if (darkIcon) darkIcon.style.display = "none";
    } else {
      body.classList.remove("theme-dark");
      body.classList.add("theme-light");
      if (lightIcon) lightIcon.style.display = "none";
      if (darkIcon) darkIcon.style.display = "inline";
    }
  }

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
