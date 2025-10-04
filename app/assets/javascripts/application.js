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
});

function setupSimpleFileUploadComponents() {
  const uploaders = document.querySelectorAll(
    "simple-file-upload[data-hidden-input]"
  );

  if (!uploaders.length) {
    return;
  }

  uploaders.forEach(function (uploader) {
    if (uploader.dataset.simpleFileUploadBound === "true") {
      return;
    }

    const hiddenInputId = uploader.dataset.hiddenInput;
    const hiddenInput = document.getElementById(hiddenInputId);

    if (!hiddenInput) {
      return;
    }

    uploader.addEventListener("change", function (event) {
      const files = event.detail ? event.detail.allFiles || [] : [];
      const firstFile = files[0];
      hiddenInput.value = firstFile ? firstFile.cdnUrl : "";
    });

    uploader.dataset.simpleFileUploadBound = "true";
  });

  document
    .querySelectorAll('[data-behavior="clear-profile-picture"]')
    .forEach(function (button) {
      if (button.dataset.simpleFileUploadBound === "true") {
        return;
      }

      button.addEventListener("click", function () {
        const targetId = button.dataset.target;
        const hiddenInput = document.getElementById(targetId);
        if (hiddenInput) {
          hiddenInput.value = "";
        }

        const previewContainer = button.closest(
          "[data-profile-picture-preview]"
        );
        if (previewContainer) {
          previewContainer.remove();
        }
      });

      button.dataset.simpleFileUploadBound = "true";
    });
}

document.addEventListener("DOMContentLoaded", setupSimpleFileUploadComponents);
document.addEventListener("turbolinks:load", setupSimpleFileUploadComponents);
