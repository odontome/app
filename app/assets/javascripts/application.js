
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

// This function prevents the session from ending
window.iCallServerId = setInterval(function (){ var remoteURL = '/'; $.get(remoteURL); }, 900000);

// Theme switcher - FOUC prevention (runs immediately when DOM is ready)
document.addEventListener('DOMContentLoaded', function() {
  // Apply theme immediately to prevent FOUC
  const theme = localStorage.getItem('theme') || 'light';
  const body = document.getElementById('app-body') || document.body;
  if (theme === 'dark') {
    body.classList.remove('theme-light');
    body.classList.add('theme-dark');
  }
});

$(function(){
  const popoverTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="popover"]'))
  popoverTriggerList.map(function (popoverTriggerEl) {
    return new bootstrap.Popover(popoverTriggerEl)
  });

  const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
  tooltipTriggerList.map(function (tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl)
  });

  // Wrap every rails date_select element in a column
  $('select[class*="date-select"]').wrap('<div class="col-4" />');

  // Theme Switcher functionality
  const themeToggleNavbar = document.getElementById('theme-toggle-navbar');
  const themeToggleDropdown = document.getElementById('theme-toggle-dropdown');
  const themeText = document.querySelector('.theme-text');
  const lightIcons = document.querySelectorAll('.light-icon');
  const darkIcons = document.querySelectorAll('.dark-icon');
  const body = document.body;

  // Get current theme from localStorage or default to light
  const currentTheme = localStorage.getItem('theme') || 'light';
  
  // Apply the current theme
  applyTheme(currentTheme);

  // Theme toggle click handler for both elements
  function handleThemeToggle(e) {
    e.preventDefault();
    const newTheme = body.classList.contains('theme-dark') ? 'light' : 'dark';
    applyTheme(newTheme);
    localStorage.setItem('theme', newTheme);
  }

  if (themeToggleNavbar) {
    themeToggleNavbar.addEventListener('click', handleThemeToggle);
  }

  if (themeToggleDropdown) {
    themeToggleDropdown.addEventListener('click', handleThemeToggle);
  }

  function applyTheme(theme) {
    if (theme === 'dark') {
      body.classList.remove('theme-light');
      body.classList.add('theme-dark');
      if (themeText) themeText.textContent = 'Light Mode';
      lightIcons.forEach(icon => icon.style.display = 'none');
      darkIcons.forEach(icon => icon.style.display = 'inline');
    } else {
      body.classList.remove('theme-dark');
      body.classList.add('theme-light');
      if (themeText) themeText.textContent = 'Dark Mode';
      lightIcons.forEach(icon => icon.style.display = 'inline');
      darkIcons.forEach(icon => icon.style.display = 'none');
    }
  }
});

