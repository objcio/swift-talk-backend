(() => {
  const form = document.querySelector('.search-form');
  if (form) {
    const search = form.querySelector('[name=q]');
    const collection = form.querySelector('[name=collection]');
    const normalize = value => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
    const episodes = [...document.querySelectorAll('[data-episode]')].map(element => ({
      element,
      search: normalize(element.dataset.search),
      collections: element.dataset.collections.split(' '),
    }));
    function filter(updateURL = true) {
      const words = normalize(search.value).trim().split(/\s+/).filter(Boolean);
      let count = 0;
      for (const episode of episodes) {
        const matches = words.every(word => episode.search.includes(word)) &&
          (!collection.value || episode.collections.includes(collection.value));
        episode.element.hidden = !matches;
        if (matches) count++;
      }
      document.querySelector('.result-count').textContent = `${count} ${count === 1 ? 'episode' : 'episodes'}`;
      document.querySelector('.no-results').hidden = count !== 0;
      if (updateURL) {
        const url = new URL(location.href);
        for (const [key, value] of [['q', search.value], ['collection', collection.value]]) {
          if (value) url.searchParams.set(key, value);
          else url.searchParams.delete(key);
        }
        history.replaceState(null, '', url);
      }
    }
    function restore() {
      const params = new URLSearchParams(location.search);
      search.value = params.get('q') || '';
      collection.value = params.get('collection') || '';
      filter(false);
    }
    form.hidden = false;
    form.addEventListener('submit', event => { event.preventDefault(); filter(); });
    form.addEventListener('input', () => filter());
    form.addEventListener('change', () => filter());
    form.addEventListener('reset', () => { search.value = ''; collection.value = ''; filter(); });
    window.addEventListener('popstate', restore);
    restore();
  }

  const iframe = document.querySelector('#vimeo-player');
  if (!iframe) return;
  const status = document.querySelector('#player-status');
  const player = window.Vimeo ? new window.Vimeo.Player(iframe) : null;
  const baseEmbed = iframe.src;
  if (player) {
    player.ready().catch(error => {
      status.hidden = false;
      status.textContent = error.name === 'PrivacyError'
        ? 'This video’s privacy settings prevent playback here. You can read the full transcript below.'
        : 'The video could not load. You can read the full transcript below.';
    });
  }
  function seconds(value) {
    return value !== null && /^\d+$/.test(value) && Number.isSafeInteger(Number(value)) ? Number(value) : null;
  }
  async function seek(time, play = false) {
    if (player) {
      try {
        await player.setCurrentTime(time);
        if (play) await player.play();
        status.hidden = true;
      } catch {
        status.hidden = false;
        status.textContent = 'The video could not seek to this timestamp. Use the Vimeo player controls to continue.';
      }
    } else {
      // Keep timestamp links useful if the optional player API could not load.
      iframe.src = `${baseEmbed}#t=${time}s`;
    }
  }
  document.querySelectorAll('.transcript a[href^="?t="]').forEach(link => {
    const time = seconds(new URL(link.href).searchParams.get('t'));
    if (time !== null) link.dataset.time = String(time);
  });
  document.addEventListener('click', event => {
    const link = event.target.closest('a[data-time]');
    if (!link || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const time = seconds(link.dataset.time);
    if (time === null) return;
    event.preventDefault();
    history.pushState(null, '', link.href);
    seek(time, true);
  });
  function restoreTime() {
    const time = seconds(new URLSearchParams(location.search).get('t')) ?? seconds(location.hash.slice(1));
    if (time !== null) seek(time);
  }
  window.addEventListener('popstate', restoreTime);
  window.addEventListener('hashchange', restoreTime);
  restoreTime();
})();
