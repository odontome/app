(function () {
  async function loadPatientCounts() {
    const nav = document.querySelector('[data-patient-counts-url]');
    if (!nav) return;

    const badges = Array.from(nav.querySelectorAll('[data-patient-count]'));
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 10000);

    try {
      const response = await fetch(nav.dataset.patientCountsUrl, {
        headers: { Accept: 'application/json' },
        credentials: 'same-origin',
        cache: 'no-store',
        signal: controller.signal
      });
      if (!response.ok) throw new Error('Counts unavailable');

      const counts = await response.json();
      if (!counts || !badges.every(badge => Number.isSafeInteger(counts[badge.dataset.patientCount]) && counts[badge.dataset.patientCount] >= 0)) {
        throw new Error('Invalid counts');
      }

      badges.forEach(badge => {
        badge.textContent = counts[badge.dataset.patientCount];
        badge.removeAttribute('aria-label');
        badge.removeAttribute('aria-busy');
      });
    } catch (_) {
      // Keep the patient list usable without showing a failed count as zero.
      badges.filter(badge => badge.getAttribute('aria-busy') === 'true').forEach(badge => {
        badge.classList.add('d-none');
        badge.removeAttribute('aria-busy');
      });
    } finally {
      window.clearTimeout(timeout);
    }
  }

  document.addEventListener('DOMContentLoaded', loadPatientCounts);
})();
