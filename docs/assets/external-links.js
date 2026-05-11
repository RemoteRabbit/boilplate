// Open links to other domains in a new tab, with rel="noopener noreferrer".
// Scoped to <article> so header/footer/sidebar nav stays in-tab.
// Re-runs on every page render to support Zensical/Material's instant
// (SPA) navigation via the document$ observable.

(function () {
  function update() {
    var host = location.hostname;
    document.querySelectorAll('article a[href]').forEach(function (a) {
      var href = a.getAttribute('href');
      if (!href || href[0] === '#' || href.indexOf('://') === -1) return;
      try {
        if (new URL(a.href).hostname !== host) {
          a.target = '_blank';
          a.rel = 'noopener noreferrer';
        }
      } catch (_) { /* malformed URL: ignore */ }
    });
  }

  if (window.document$ && typeof window.document$.subscribe === 'function') {
    window.document$.subscribe(update);
  } else {
    document.addEventListener('DOMContentLoaded', update);
  }
})();
