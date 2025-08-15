document.addEventListener("click", function (e) {
  const el = e.target.closest("[data-clipboard]");
  if (!el) return;

  e.preventDefault();
  const text = el.dataset.clipboard;
  if (!text) return;

  if (navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(text);
  } else {
    // Fallback for older browsers
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.left = "-9999px";
    document.body.appendChild(ta);
    ta.select();
    try {
      document.execCommand("copy");
    } catch {}
    document.body.removeChild(ta);
  }
});
