// Listen for clicks on [data-clipboard] links
document.addEventListener("click", function (e) {
  const el = e.target.closest("[data-clipboard]");
  if (!el) return;

  e.preventDefault();
  const text = el.dataset.clipboard;
  if (!text) return;

  // Find the dropdown button (parent of the clicked element)
  const dropdown = el.closest(".dropdown");
  const dropdownButton = dropdown
    ? dropdown.querySelector(".dropdown-toggle")
    : null;
  const originalText = dropdownButton
    ? dropdownButton.textContent.trim()
    : null;

  // Close the dropdown
  if (dropdown) {
    const dropdownMenu = dropdown.querySelector(".dropdown-menu");
    if (dropdownMenu) {
      dropdownMenu.classList.remove("show");
    }
    if (dropdownButton) {
      dropdownButton.setAttribute("aria-expanded", "false");
    }
  }

  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(text);
  }
});
