document.addEventListener("click", async function (event) {
  const button = event.target.closest("[data-ai-copy]");
  if (!button) return;

  const container = button.closest("[data-ai-copy-container]");
  const input = container.querySelector("input");
  const status = container.querySelector("[data-ai-copy-status]");
  try {
    await navigator.clipboard.writeText(input.value);
    status.textContent = button.dataset.copied;
  } catch (_error) {
    input.focus();
    input.select();
    status.textContent = button.dataset.copyFailed;
  }
});

document.addEventListener("change", function (event) {
  const control = event.target.closest("[data-ai-access-control]");
  if (!control) return;

  const form = control.closest("[data-ai-access-form]");
  const toggle = form.querySelector("[data-ai-access-toggle]");
  const consent = form.querySelector("[data-ai-consent]");

  if (control === toggle && toggle.checked && consent && !consent.checked) {
    consent.focus();
    return;
  }

  if (control === toggle && !toggle.checked && !window.confirm(toggle.dataset.disableConfirm)) {
    toggle.checked = true;
    return;
  }

  if (control === consent && !toggle.checked) return;

  form.requestSubmit();
});
