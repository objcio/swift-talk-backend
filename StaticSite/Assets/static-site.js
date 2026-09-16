(() => {
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
