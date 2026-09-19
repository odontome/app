document.addEventListener('DOMContentLoaded', function () {
  const button = document.querySelector('[data-print-report]');
  if (button) button.addEventListener('click', function () { window.print(); });
});
